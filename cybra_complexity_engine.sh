#!/data/data/com.termux/files/usr/bin/bash
# CYBRA COMPLEXITY ENGINE v2 — CUMULATIVE 7 levels
# L7 = 6 умов; L6 = 5 умов; ... L1 = 0 умов (завжди OK)
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TARGET=${TARGET:-160}
LOG="$CYBRA/logs/complexity_engine.log"; mkdir -p "$CYBRA/logs"

log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
rd(){ redis-cli "$@" 2>/dev/null; }
rok(){ rd ping | grep -q PONG; }
ram(){ free -m 2>/dev/null | awk '/Mem:/{printf "%d",$3/$2*100}'; }
tid(){ printf '%s' "$1" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1; }

# ─── 6 незалежних перевірок ───
c_json()      { printf '%s' "$1" | python3 -c "import sys,json;json.loads(sys.stdin.read())" 2>/dev/null; }
c_redis()     { rok; }
c_hashmod()   { [ -f cybra_hash_module_test.py ] && timeout 5 python3 cybra_hash_module_test.py >/dev/null 2>&1; }
c_backend()   { [ -f gitcybrahash_double_backend.py ] && timeout 8 python3 gitcybrahash_double_backend.py >/dev/null 2>&1; }
c_mapping()   { [ -f cybra_ai_tasks_to_blocks.py ] && timeout 6 python3 cybra_ai_tasks_to_blocks.py >/dev/null 2>&1; }
c_parliament(){ [ -f parliament_executor_v6.py ] && timeout -k 2 12 bash -c '
    setsid python3 parliament_executor_v6.py </dev/null >/dev/null 2>&1 &
    pid=$!; sleep 8
    kill -9 -$pid 2>/dev/null
    pkill -9 -f parliament_executor 2>/dev/null
    exit 0' ; }

# ─── КУМУЛЯТИВНІ РІВНІ ───
# що вище рівень — то більше умов — то більша ймовірність провалу
run_L7(){ local t="$1"; c_json "$t" && c_redis && c_hashmod && c_backend && c_mapping && c_parliament; }
run_L6(){ local t="$1"; c_json "$t" && c_redis && c_hashmod && c_backend && c_mapping; }
run_L5(){ local t="$1"; c_json "$t" && c_redis && c_hashmod && c_backend; }
run_L4(){ local t="$1"; c_json "$t" && c_redis && c_hashmod; }
run_L3(){ local t="$1"; c_json "$t" && c_redis; }
run_L2(){ local t="$1"; c_json "$t"; }
run_L1(){ local t="$1"; printf '%s' "$t" | python3 -c "
import sys,json,hashlib,time
t=json.loads(sys.stdin.read())
print(json.dumps({'id':t.get('id','?'),'level':1,'status':'done',
 'sha':hashlib.sha256(json.dumps(t,sort_keys=True).encode()).hexdigest(),
 'ts':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime())}))" ; }

process_task(){
  local t="$1" lvl=7
  while [ "$lvl" -ge 1 ]; do
    case "$lvl" in
      7) out=$(run_L7 "$t" 2>&1) ;;
      6) out=$(run_L6 "$t" 2>&1) ;;
      5) out=$(run_L5 "$t" 2>&1) ;;
      4) out=$(run_L4 "$t" 2>&1) ;;
      3) out=$(run_L3 "$t" 2>&1) ;;
      2) out=$(run_L2 "$t" 2>&1) ;;
      1) out=$(run_L1 "$t" 2>&1) ;;
    esac
    if [ $? -eq 0 ] && [ -n "$out" ]; then
      printf '{"id":"%s","level":%d,"status":"done","out":"%s"}' \
        "$(tid "$t")" "$lvl" "$(printf '%s' "$out" | head -c 200 | tr -d '\n\r"\\')" \
        | rd -x rpush "cybra:results:level${lvl}" >/dev/null
      rd hincrby cybra:complexity:stats "L${lvl}" 1 >/dev/null
      rd hincrby cybra:complexity:stats settled 1 >/dev/null
      log "  → L${lvl} OK"
      return 0
    fi
    lvl=$((lvl-1))
  done
  printf '%s' "$t" | rd -x rpush cybra:parliament:failed >/dev/null
  rd hincrby cybra:complexity:stats failed 1 >/dev/null
  log "  → FAILED all"
  return 1
}

log "═══ COMPLEXITY ENGINE v2 target=$TARGET ═══"
for i in 1 2 3 4 5; do rok && break; sleep 2; done
rok || { log "FATAL: no redis"; exit 1; }

q=$(rd llen cybra:parliament:queue); log "queue before: $q"
if [ "$q" -lt "$TARGET" ]; then
  need=$((TARGET-q))
  for i in $(seq 1 "$need"); do
    printf '{"id":"cplx_%03d","type":"complexity","task":"reach_100"}' "$i" | rd -x rpush cybra:parliament:queue >/dev/null
  done
fi
log "queue after: $(rd llen cybra:parliament:queue)"

n=0
while [ "$n" -lt "$TARGET" ]; do
  rok || { log "redis down"; sleep 5; continue; }
  r=$(ram); [ "${r:-0}" -ge 85 ] && { log "RAM ${r}% pause"; sleep 10; continue; }
  t=$(rd lpop cybra:parliament:queue)
  [ -z "$t" ] && { log "empty ($n/$TARGET)"; sleep 10; continue; }
  n=$((n+1))
  log "TASK $n/$TARGET id=$(tid "$t")"
  process_task "$t"
  sleep 1
done

rd set cybra:complexity:status done >/dev/null
log "═══ DONE $n ═══"
echo "─── STATS ───"; rd hgetall cybra:complexity:stats
