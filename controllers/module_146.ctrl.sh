#!/data/data/com.termux/files/usr/bin/bash
set -u
MODULE="$1"
LOG="$HOME/CYBRA/logs/ctrl_146.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
log "START ctrl_146"
[ -f "$MODULE" ] || { log "ERR missing"; echo "❌ missing"; exit 2; }
bash -n "$MODULE" 2>/dev/null || { log "ERR syntax"; echo "❌ syntax"; exit 3; }
out=$(echo "" | bash "$MODULE" list 2>&1); rc=$?
lines=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
if [ "$rc" -eq 0 ] && [ "$lines" -ge 2 ]; then
  printf '%s\n' "$out"; log "OK rc=$rc lines=$lines"; exit 0
else
  echo "❌ failed rc=$rc lines=$lines"; log "FAIL rc=$rc lines=$lines"; exit 1
fi
