#!/data/data/com.termux/files/usr/bin/bash
# v3 — 7 рівнів БЕЗ зовнішніх скриптів. Рівень = реальна дія з наростаючою складністю.
# L7 створить файл в evo/, L5 — в sandbox/, L1 — лише Redis.
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TARGET=${TARGET:-40}  # менше, бо кожен L7 робить реальну роботу
LOG="$CYBRA/logs/complexity_v3.log"; mkdir -p "$CYBRA/logs"
log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
rd(){ redis-cli "$@" 2>/dev/null; }
rok(){ rd ping | grep -q PONG; }
ram(){ free -m 2>/dev/null | awk '/Mem:/{printf "%d",$3/$2*100}'; }
tid(){ printf '%s' "$1" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1; }

# ─── ДІЇ (кожен рівень = СВОЯ реальна дія) ───
L7_pipeline(){  # найскладніше: evo/ + hash + verify + log + redis
  local id=$(tid "$1")
  local dir="evo/cplx_$id"; mkdir -p "$dir" || return 1
  printf '%s\n' "$1" > "$dir/task.json" || return 1
  local h=$(sha256sum "$dir/task.json" | awk '{print $1}') || return 1
  printf '{"id":"%s","sha":"%s","ts":"%s"}\n' "$id" "$h" "$(date -u +%FT%TZ)" > "$dir/proof.json" || return 1
  [ -s "$dir/proof.json" ] || return 1
  rd set "cybra:evo:$id" "$h" >/dev/null || return 1
  echo "L7 $dir"
}
L6_hashing(){   # evo/ + hash, без verify
  local id=$(tid "$1"); local dir="evo/cplx_$id"; mkdir -p "$dir" || return 1
  printf '%s\n' "$1" > "$dir/task.json" || return 1
  sha256sum "$dir/task.json" | awk '{print $1}' > "$dir/hash.txt" || return 1
  echo "L6 $dir"
}
L5_sandbox(){   # sandbox/, без evo/
  local id=$(tid "$1"); local dir="sandbox/cplx_$id"; mkdir -p "$dir" || return 1
  printf '%s\n' "$1" > "$dir/task.json" || return 1
  echo "L5 $dir"
}
L4_hashonly(){  # hash в Redis, без файлів
  local id=$(tid "$1")
  local h=$(printf '%s' "$1" | sha256sum | awk '{print $1}')
  rd set "cybra:hash:$id" "$h" >/dev/null || return 1
  echo "L4 hash $id"
}
L3_redisset(){  # просто запис в Redis
  local id=$(tid "$1")
  rd set "cybra:ack:$id" "$(date +%s)" >/dev/null || return 1
  echo "L3 ack $id"
}
L2_jsonparse(){  # тільки валідація json
  printf '%s' "$1" | python3 -c "import sys,json;json.loads(sys.stdin.read())" 2>/dev/null || return 1
  echo "L2 valid"
}
L1_log(){        # завжди OK
  local id=$(tid "$1")
  echo "L1 ack $id"
}

process_task(){
  local t="$1" fn
  for lvl in 7 6 5 4 3 2 1; do
    case $lvl in
      7) fn=L7_pipeline ;;
      6) fn=L6_hashing ;;
      5) fn=L5_sandbox ;;
      4) fn=L4_hashonly ;;
      3) fn=L3_redisset ;;
      2) fn=L2_jsonparse ;;
      1) fn=L1_log ;;
    esac
    if out=$("$fn" "$t" 2>&1) && [ -n "$out" ]; then
      rd hincrby cybra:complexity:stats "L$lvl" 1 >/dev/null
      rd hincrby cybra:complexity:stats settled 1 >/dev/null
      log "  → L$lvl OK : $out"
      return 0
    fi
  done
  rd hincrby cybra:complexity:stats failed 1 >/dev/null
  log "  → FAILED"
  return 1
}

log "═══ v3 target=$TARGET ═══"
for i in 1 2 3 4 5; do rok && break; sleep 2; done
rok || { log "no redis"; exit 1; }

q=$(rd llen cybra:parliament:queue); log "queue: $q"
if [ "$q" -lt "$TARGET" ]; then
  for i in $(seq $((q+1)) "$TARGET"); do
    printf '{"id":"v3_%03d","type":"complexity","task":"reach_100"}' "$i" | rd -x rpush cybra:parliament:queue >/dev/null
  done
fi
log "queue filled: $(rd llen cybra:parliament:queue)"

n=0
while [ "$n" -lt "$TARGET" ]; do
  rok || { sleep 5; continue; }
  r=$(ram); [ "${r:-0}" -ge 85 ] && { log "RAM ${r}%"; sleep 10; continue; }
  t=$(rd lpop cybra:parliament:queue); [ -z "$t" ] && { sleep 5; continue; }
  n=$((n+1)); log "TASK $n/$TARGET id=$(tid "$t")"
  process_task "$t"; sleep 1
done
rd set cybra:complexity:status done >/dev/null
log "═══ DONE $n ═══"
rd hgetall cybra:complexity:stats | paste - - | sort
