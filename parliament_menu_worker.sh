#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/menu_worker.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
log "═══ MENU WORKER START ═══"
while :; do
  raw=$(redis-cli rpop cybra:parliament:queue 2>/dev/null)
  [ -z "$raw" ] && { sleep 2; continue; }
  action=$(echo "$raw" | python3 -c "import sys,json;print(json.load(sys.stdin).get('action',''))" 2>/dev/null)
  [ -z "$action" ] && { redis-cli rpush cybra:parliament:failed "$raw" >/dev/null; continue; }
  script=$(redis-cli hget cybra:executor:mapping "$action" 2>/dev/null)
  [ -z "$script" ] && { redis-cli rpush cybra:parliament:failed "$raw" >/dev/null; log "no map: $action"; continue; }
  out=$(bash "$CYBRA/$script" "$raw" 2>&1); rc=$?
  status=$([ $rc -eq 0 ] && echo done || echo failed)
  result="{\"action\":\"$action\",\"status\":\"$status\",\"rc\":$rc,\"ts\":\"$(date -u +%FT%TZ)\"}"
  redis-cli rpush cybra:parliament:results "$result" >/dev/null
  log "$action → $status"
done
