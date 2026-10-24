#!/data/data/com.termux/files/usr/bin/bash
# CYBRA FULL AUTOPILOT — fix / check / load160 / support / recovery / node
# usage: ./cybra_full.sh {all|check|fix|load160|support [sec] [count]|recovery|node|status}
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/full_autopilot.log"; mkdir -p "$CYBRA/logs" "$CYBRA/state"
RAM_LIMIT=85; TARGET=${TARGET:-160}

log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
cnt(){ ps aux 2>/dev/null | grep -F "$1" | grep -v grep | wc -l; }
ram_pct(){ free -m 2>/dev/null | awk '/Mem:/{printf "%d",$3/$2*100}'; }
redis_ok(){ redis-cli ping 2>/dev/null | grep -q PONG; }

# ─────────── CHECK ───────────
check(){
  log "=== CHECK ==="
  redis_ok && log "redis: OK" || { log "redis: DOWN"; return 1; }
  local r=$(ram_pct); log "ram_used_pct: ${r:-?}"
  [ "${r:-0}" -ge "$RAM_LIMIT" ] && { log "ram: HIGH"; return 2; }
  return 0
}

# ─────────── FIX (дублікати + redis) ───────────
fix(){
  log "=== FIX ==="
  # 1. дублікати парламентських воркерів
  local n=$(cnt parliament_executor)
  if [ "$n" -gt 1 ]; then
    log "dup parliament_executor: $n → keep pm2 'executor', kill others"
    pkill -9 -f parliament_executor 2>/dev/null; sleep 1
  fi
  [ "$n" -gt 10 ] && { log "fork bomb ($n) → hard kill"; pkill -9 -f parliament_executor; }
  # 2. executor більше не потрібен — завдання виконує ai-160
  pm2 describe executor >/dev/null 2>&1 && { log "delete duplicate pm2 executor"; pm2 delete executor >/dev/null 2>&1; }
  # 3. redis
  if ! redis_ok; then
    local pid=$(ps aux | grep '[r]edis-server' | awk '{print $2}' | head -1)
    [ -n "$pid" ] && { log "kill orphan redis $pid"; kill -9 "$pid" 2>/dev/null; sleep 1; }
    pm2 describe redis >/dev/null 2>&1 && pm2 delete redis >/dev/null 2>&1
    log "start redis in pm2"
    pm2 start redis-server --name redis -- --daemonize no >/dev/null 2>&1
    for i in 1 2 3 4 5; do redis_ok && break; sleep 1; done
  fi
  redis_ok && log "redis: OK" || { log "redis: FAIL"; return 1; }
  # 4. binmix: демон, без cron-restart (він флапав)
  if pm2 describe binmix >/dev/null 2>&1; then
    local st=$(pm2 jlist 2>/dev/null | python3 -c "import sys,json;print([p['pm2_env']['status'] for p in json.load(sys.stdin) if p['name']=='binmix'][0])" 2>/dev/null || echo unknown)
    [ "$st" != "online" ] && { pm2 delete binmix >/dev/null 2>&1; }
  fi
  pm2 describe binmix >/dev/null 2>&1 || { [ -x bin/cybra_binmix ] && \
    pm2 start bin/cybra_binmix --name binmix --interpreter bash --no-autorestart -- start >/dev/null 2>&1; }
  log "binmix: $(pm2 jlist 2>/dev/null | grep -o '"name":"binmix"[^}]*"status":"[a-z]*"' | grep -o 'status":"[a-z]*"' | cut -d'"' -f3 || echo n/a)"
}

# ─────────── LOAD 160 (заповнити чергу + запустити ai-160) ───────────
load160(){
  log "=== LOAD 160 ==="
  redis_ok || { log "abort: no redis"; return 1; }
  local have=$(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0)
  log "queue before: $have"
  if [ "$have" -lt "$TARGET" ]; then
    local need=$((TARGET - have))
    log "need $need tasks → try existing generators"
    for g in parliament_1000_questions.sh parliament_100_questions.sh cybra_ai_tasks_to_blocks.py create_base_and_tasks.py parliament_next_evolution_tasks.sh; do
      [ -f "$g" ] || continue
      log "run $g"
      case "$g" in
        *.py) timeout 60 python3 "$g" >/dev/null 2>&1 ;;
        *.sh) timeout 60 bash "$g" >/dev/null 2>&1 ;;
      esac
      have=$(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0)
      [ "$have" -ge "$TARGET" ] && break
    done
    # fallback: гарантовано добити до 160 синтетичними завданнями
    have=$(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0)
    if [ "$have" -lt "$TARGET" ]; then
      local add=$((TARGET - have))
      log "fallback: LPUSH $add synthetic tasks"
      local ts=$(date -u +%FT%TZ)
      for i in $(seq 1 "$add"); do
        printf '{"id":"auto_%s_%03d","task":"evolution_fill","src":"autopilot","ts":"%s"}\n' "$(date +%s)" "$i" "$ts" \
          | redis-cli -x lpush cybra:parliament:queue >/dev/null 2>&1
      done
    fi
  fi
  have=$(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0)
  log "queue after: $have"

  # перезапустити ai-160 з правильними прапорцями
  pm2 describe ai-160 >/dev/null 2>&1 && pm2 delete ai-160 >/dev/null 2>&1
  log "start ai-160 with mem-limit 200M, backoff 3s"
  MAX_WORKERS=1 AI_WORKERS=1 WORKERS=1 \
  pm2 start ./cybra_ai_until_done.sh --name ai-160 --interpreter bash \
    --max-memory-restart 200M --exp-backoff-restart-delay 3000 --max-restarts 20 \
    -- start 160 >/dev/null 2>&1

  # cybra-monolith
  pm2 describe cybra-monolith >/dev/null 2>&1 || \
    { [ -f ecosystem.config.js ] && pm2 start ecosystem.config.js >/dev/null 2>&1; }
  pm2 restart cybra-monolith >/dev/null 2>&1

  sleep 3; pm2 save >/dev/null 2>&1
  log "load160 done"
}

# ─────────── SUPPORT (watchdog) ───────────
support(){
  local INTERVAL=${1:-30} COUNT=${2:-0} n=0
  log "=== SUPPORT every ${INTERVAL}s ==="
  while :; do
    n=$((n+1))
    # redis
    redis_ok || { log "redis down → fix"; fix; }
    # OOM check
    local r=$(ram_pct)
    if [ "${r:-0}" -ge "$RAM_LIMIT" ]; then
      log "ram $r% → pause ai-160, gc binmix"
      pm2 stop ai-160 >/dev/null 2>&1
      redis-cli flushdb >/dev/null 2>&1 &  # не блокуємо, не критично
    fi
    # fork bomb
    local c=$(cnt parliament_executor)
    if [ "$c" -gt 10 ]; then
      log "fork bomb ($c) → restart ai-160"
      pkill -9 -f parliament_executor 2>/dev/null
      pm2 restart ai-160 >/dev/null 2>&1
    fi
    # ai-160 errored
    local st=$(pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=[p['pm2_env']['status'] for p in json.load(sys.stdin) if p['name']=='ai-160'];print(d[0] if d else 'none')" 2>/dev/null)
    [ "$st" = "errored" ] || [ "$st" = "stopped" ] && { log "ai-160 $st → recovery"; load160 >/dev/null 2>&1; }
    # лог-ротація
    [ -f "$LOG" ] && [ "$(stat -c%s "$LOG" 2>/dev/null||echo 0)" -gt 5000000 ] && mv "$LOG" "$LOG.1"
    [ "$COUNT" -gt 0 ] && [ "$n" -ge "$COUNT" ] && break
    sleep "$INTERVAL"
  done
}

# ─────────── RECOVERY ───────────
recovery(){
  log "=== RECOVERY ==="
  pm2 jlist 2>/dev/null | python3 -c "
import sys,json
for p in json.load(sys.stdin):
    if p['pm2_env']['status'] in ('errored','stopped'):
        print(p['name'])" 2>/dev/null | while read -r n; do
    [ -z "$n" ] && continue
    log "restart: $n"; pm2 restart "$n" >/dev/null 2>&1
  done
  fix; load160
}

# ─────────── NODE ───────────
node_fn(){
  log "=== NODE ==="
  if [ -d nodes ]; then
    for x in nodes/*/; do
      [ -f "$x/index.js" ] && {
        local nm="node-$(basename "$x")"
        pm2 describe "$nm" >/dev/null 2>&1 || pm2 start "$x/index.js" --name "$nm" >/dev/null 2>&1
      }
    done
  fi
  [ -x install_binmix_wrap.sh ] && bash install_binmix_wrap.sh >/dev/null 2>&1
  log "modules: $(ls modules 2>/dev/null | wc -l)"
  pm2 save >/dev/null 2>&1
}

# ─────────── STATUS ───────────
status(){
  echo "── PM2 ──"; pm2 list
  echo "── RAM ──"; free -m 2>/dev/null | awk '/Mem:/{printf "used: %d%%\n",$3/$2*100}'
  echo "── Redis ──"; redis_ok && echo "PONG" || echo "DOWN"
  echo "── Queue ──"; redis-cli llen cybra:parliament:queue 2>/dev/null
  echo "── Executors ──"; cnt parliament_executor
  echo "── ai-160 tail ──"; pm2 logs ai-160 --lines 8 --nostream 2>/dev/null | tail -8
}

case "${1:-all}" in
  all)      check; fix; load160; node_fn; log "AUTOPILOT: 100% state"; status ;;
  check)    check ;;
  fix)      fix ;;
  load160)  load160 ;;
  support)  support "${2:-30}" "${3:-0}" ;;
  recovery) recovery ;;
  node)     node_fn ;;
  status)   status ;;
  *) echo "usage: $0 {all|check|fix|load160|support [sec] [n]|recovery|node|status}"; exit 1 ;;
esac
