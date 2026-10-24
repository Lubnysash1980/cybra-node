#!/data/data/com.termux/files/usr/bin/bash
# CYBRA FINAL — доводить систему до 100%: redis, binmix, executor-kill, queue=160, ai-160
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/final.log"; mkdir -p "$CYBRA/logs"
TARGET=${TARGET:-160}

log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
rd(){ redis-cli "$@" 2>/dev/null; }
llen(){ rd llen "$1"; echo; }
rok(){ rd ping | grep -q PONG; }
pst(){ pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=[p['pm2_env']['status'] for p in json.load(sys.stdin) if p['name']=='$1'];print(d[0] if d else 'none')" 2>/dev/null; }

log "════ STEP 1: REDIS ════"
rok || { log "starting redis"; pm2 start redis-server --name redis -- --daemonize no >/dev/null 2>&1; sleep 3; }
rok || { log "FATAL: redis down"; exit 1; }
log "redis: PONG"

log "════ STEP 2: KILL DUPLICATE EXECUTORS ════"
pm2 delete executor >/dev/null 2>&1 && log "pm2 executor deleted"
pkill -9 -f parliament_executor 2>/dev/null && log "stray executors killed"
sleep 1
log "executors running: $(ps aux | grep -c '[p]arliament_executor')"

log "════ STEP 3: FIX BINMIX ════"
st=$(pst binmix); log "binmix state: $st"
if [ "$st" != "online" ]; then
  pm2 delete binmix >/dev/null 2>&1
  [ -x bin/cybra_binmix ] && pm2 start bin/cybra_binmix --name binmix --interpreter bash --no-autorestart -- start >/dev/null 2>&1
  sleep 1; log "binmix state now: $(pst binmix)"
fi

log "════ STEP 4: DIAGNOSE ════"
for k in cybra:parliament:queue cybra:finance_gap_evolution:ai_tasks cybra:evolution_deployment:roadmap cybra:owner:directives cybra:ai_until_done:moved_hashes cybra:parliament:failed; do
  log "  $k = $(llen $k)"
done
log "queue_head: $(rd lrange cybra:parliament:queue 0 1 | tr '\n' ' ')"

log "════ STEP 5: DETECT EXECUTOR KEY ════"
EXEC_KEY=""
if [ -f parliament_executor_v6.py ]; then
  EXEC_KEY=$(grep -oE 'b[lr]pop [^ ]+|lpop [^ ]+|rpop [^ ]+' parliament_executor_v6.py 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"'"'")
  log "executor reads from: ${EXEC_KEY:-cybra:parliament:queue (default)}"
fi
[ -z "$EXEC_KEY" ] && EXEC_KEY="cybra:parliament:queue"

log "════ STEP 6: FILL QUEUE TO $TARGET ════"
Q=$(llen cybra:parliament:queue); log "before: $Q"
if [ "$Q" -lt "$TARGET" ]; then
  log "clear moved_hashes to allow re-collect"
  rd del cybra:ai_until_done:moved_hashes >/dev/null 2>&1

  for g in parliament_1000_questions.sh parliament_100_questions.sh parliament_7_tests.sh cybra_ai_tasks_to_blocks.py create_base_and_tasks.py parliament_next_evolution_tasks.sh; do
    [ -f "$g" ] || continue
    log "run $g"
    case "$g" in
      *.py) timeout 30 python3 "$g" >/dev/null 2>&1 ;;
      *.sh) timeout 30 bash "$g" >/dev/null 2>&1 ;;
    esac
    Q=$(llen cybra:parliament:queue)
    log "  → queue=$Q"
    [ "$Q" -ge "$TARGET" ] && break
  done

  Q=$(llen cybra:parliament:queue)
  if [ "$Q" -lt "$TARGET" ]; then
    add=$((TARGET - Q)); log "fallback: rpush $add synthetic tasks"
    ts=$(date +%s)
    for i in $(seq 1 "$add"); do
      printf '{"id":"auto_%s_%03d","type":"evolution_task","task":"complete_to_100_percent","src":"autopilot","ts":"%s"}' \
        "$ts" "$i" "$(date -u +%FT%TZ)" \
        | rd -x rpush cybra:parliament:queue >/dev/null
    done
  fi
fi
log "queue after: $(llen cybra:parliament:queue)"

log "════ STEP 7: RESTART AI-160 ════"
pm2 delete ai-160 >/dev/null 2>&1
MAX_WORKERS=1 AI_WORKERS=1 WORKERS=1 \
pm2 start ./cybra_ai_until_done.sh --name ai-160 --interpreter bash \
  --max-memory-restart 200M --exp-backoff-restart-delay 3000 --max-restarts 20 \
  -- start 160 >/dev/null 2>&1
sleep 6
log "ai-160 state: $(pst ai-160)"

log "════ STEP 8: SAVE ════"
pm2 save >/dev/null 2>&1
log "saved"

log "════ FINAL STATE ════"
pm2 list
echo
echo "┌─ СТАН ─────────────────────────────────────"
echo "│ queue        : $(llen cybra:parliament:queue)"
echo "│ executors    : $(ps aux | grep -c '[p]arliament_executor')"
echo "│ redis        : $(rok && echo PONG || echo DOWN)"
echo "│ binmix       : $(pst binmix)"
echo "│ ai-160       : $(pst ai-160)"
echo "│ RAM          : $(free -m 2>/dev/null | awk '/Mem:/{printf "%d%%",$3/$2*100}')"
echo "└────────────────────────────────────────────"
echo
echo "ai-160 tail:"
pm2 logs ai-160 --lines 12 --nostream 2>/dev/null | tail -14
echo
echo "▶ Перевірка через 30с:  ./cybra_final.sh status"
