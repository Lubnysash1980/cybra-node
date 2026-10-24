#!/data/data/com.termux/files/usr/bin/bash
# CYBRA AUTOPILOT — fix / check / load / support / recovery / node
set -u
CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/autopilot.log"
mkdir -p "$CYBRA/logs" "$CYBRA/state"
RAM_LIMIT_PCT=85

log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
count_proc(){ ps aux 2>/dev/null | grep -F "$1" | grep -v grep | wc -l; }

check(){
  log "=== CHECK ==="
  redis-cli ping 2>/dev/null | grep -q PONG \
    && log "redis: OK" || { log "redis: DOWN"; return 1; }
  local ram=$(free -m 2>/dev/null | awk '/Mem:/{printf "%d", $3/$2*100}')
  log "ram_used_pct: ${ram:-?}"
  [ "${ram:-0}" -ge "$RAM_LIMIT_PCT" ] && { log "ram: HIGH"; return 2; }
  return 0
}

fix(){
  log "=== FIX ==="
  pm2 list 2>/dev/null | grep -q "redis.*online" || {
    local pid=$(ps aux | grep redis-server | grep -v grep | awk '{print $2}' | head -1)
    [ -n "$pid" ] && { log "kill orphan redis pid=$pid"; kill -9 "$pid" 2>/dev/null; sleep 1; }
  }
  local cnt=$(count_proc parliament_executor)
  [ "$cnt" -gt 3 ] && { log "fork bomb: $cnt → kill"; pkill -9 -f parliament_executor; }
  pm2 list 2>/dev/null | grep -q "redis.*online" || {
    log "start redis under pm2"
    pm2 delete redis 2>/dev/null
    pm2 start redis-server --name redis -- --daemonize no
    sleep 2
  }
  redis-cli ping 2>/dev/null | grep -q PONG || { log "redis: FAIL"; return 1; }
  log "redis: OK"
}

load(){
  log "=== LOAD ==="
  for i in 1 2 3 4 5; do
    redis-cli ping 2>/dev/null | grep -q PONG && break; sleep 2
  done
  redis-cli ping 2>/dev/null | grep -q PONG || { log "abort: no redis"; return 1; }

  pm2 describe cybra-monolith >/dev/null 2>&1 \
    || { [ -f "$CYBRA/ecosystem.config.js" ] && pm2 start "$CYBRA/ecosystem.config.js"; }
  pm2 restart cybra-monolith 2>/dev/null

  pm2 list 2>/dev/null | grep -q "binmix.*online" \
    || { [ -x "$CYBRA/bin/cybra_binmix" ] && \
         pm2 start "$CYBRA/bin/cybra_binmix" --name binmix --interpreter bash -- start; }

  pm2 list 2>/dev/null | grep -q "ai-160.*online" || {
    MAX_WORKERS=1 AI_WORKERS=1 WORKERS=1 \
    pm2 start "$CYBRA/cybra_ai_until_done.sh" --name ai-160 \
      --interpreter bash --max-memory-restart 200M \
      --exp-backoff-restart-delay 3000 --max-restarts 20 -- start 160
  }
  sleep 3; pm2 save; log "load done"
}

support(){
  local INTERVAL=${1:-30} COUNT=${2:-0} n=0
  log "=== SUPPORT (watchdog every ${INTERVAL}s) ==="
  while :; do
    n=$((n+1)); check >/dev/null 2>&1; local rc=$?
    [ $rc -eq 1 ] && { log "redis down → fix"; fix; }
    [ $rc -eq 2 ] && { log "ram high → pause ai-160"; pm2 stop ai-160 2>/dev/null; }
    local cnt=$(count_proc parliament_executor)
    if [ "$cnt" -gt 10 ]; then
      log "fork bomb ($cnt) → restart ai-160"
      pm2 delete ai-160 2>/dev/null; sleep 2
      MAX_WORKERS=1 AI_WORKERS=1 \
        pm2 start "$CYBRA/cybra_ai_until_done.sh" --name ai-160 --interpreter bash \
          --max-restarts 20 -- start 160
    fi
    local sz=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
    [ "$sz" -gt 5000000 ] && { mv "$LOG" "$LOG.1"; : > "$LOG"; }
    [ "$COUNT" -gt 0 ] && [ "$n" -ge "$COUNT" ] && break
    sleep "$INTERVAL"
  done
}

recovery(){
  log "=== RECOVERY ==="
  pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    for p in json.load(sys.stdin):
        if p['pm2_env']['status'] in ('errored','stopped'):
            print(p['name'])
except: pass" | while read name; do
    [ -z "$name" ] && continue
    log "restart: $name"; pm2 restart "$name" 2>/dev/null
  done
  fix; load
}

node(){
  log "=== NODE ==="
  local d="$CYBRA/nodes"
  if [ -d "$d" ]; then
    ls "$d" 2>/dev/null | head -20
    for x in "$d"/*/; do
      [ -f "$x/index.js" ] && {
        local nm="node-$(basename "$x")"
        pm2 describe "$nm" >/dev/null 2>&1 || pm2 start "$x/index.js" --name "$nm"
      }
    done
  fi
  [ -x "$CYBRA/install_binmix_wrap.sh" ] && bash "$CYBRA/install_binmix_wrap.sh"
  log "modules: $(ls "$CYBRA/modules" 2>/dev/null | wc -l)"
  pm2 save
}

case "${1:-all}" in
  check)    check ;;
  fix)      fix ;;
  load)     load ;;
  support)  support "${2:-30}" "${3:-0}" ;;
  recovery) recovery ;;
  node)     node ;;
  all)      check; fix; load; node; log "AUTOPILOT: 100% state"; pm2 list ;;
  *) echo "usage: $0 {check|fix|load|support [sec] [count]|recovery|node|all}"; exit 1 ;;
esac
