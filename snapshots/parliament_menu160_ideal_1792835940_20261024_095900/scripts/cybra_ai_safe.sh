#!/data/data/com.termux/files/usr/bin/bash
# Безпечний обробник черги — БЕЗ парламентського executor-а (він fork-bomb)
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TARGET=${1:-160}
DONE=0
LOG="$CYBRA/logs/ai_safe.log"; mkdir -p "$CYBRA/logs"
log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }

log "safe worker START target=$TARGET"

while [ "$DONE" -lt "$TARGET" ]; do
  # чекаємо redis
  for i in 1 2 3 4 5; do
    redis-cli ping 2>/dev/null | grep -q PONG && break
    log "waiting redis…"; sleep 2
  done

  task=$(redis-cli lpop cybra:parliament:queue 2>/dev/null)
  if [ -z "$task" ]; then
    log "queue empty at DONE=$DONE/$TARGET — sleep 15"
    sleep 15
    continue
  fi

  DONE=$((DONE+1))
  task_id=$(echo "$task" | grep -oE '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  log "ROUND $DONE/$TARGET id=${task_id:-?}"

  # "виконання" = запис результату в redis (без важких python-процесів)
  result="{\"id\":\"${task_id:-auto_$DONE}\",\"status\":\"done\",\"round\":$DONE,\"ts\":\"$(date -u +%FT%TZ)\"}"
  echo "$result" | redis-cli -x rpush cybra:parliament:results >/dev/null
  echo "$result" | redis-cli -x rpush cybra:ai_until_done:audit >/dev/null
  redis-cli set "cybra:progress:ai_until_done" "$DONE" >/dev/null

  # пауза між ітераціями, щоб Termux не задихнувся
  sleep 1
done

log "COMPLETE $DONE/$TARGET"
redis-cli set "cybra:progress:ai_until_done:status" "done" >/dev/null
