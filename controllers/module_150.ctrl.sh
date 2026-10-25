#!/data/data/com.termux/files/usr/bin/bash
set -u
MODULE="$1"; shift
LOG="$HOME/CYBRA/logs/ctrl_150.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
log "START ctrl_150 args=$#"
[ -f "$MODULE" ] || { log "ERR missing"; echo "❌ missing"; exit 2; }
bash -n "$MODULE" 2>/dev/null || { log "ERR syntax"; echo "❌ syntax"; exit 3; }
if [ $# -gt 0 ]; then ARGS=("$@"); else ARGS=("list"); fi
log "exec: bash $MODULE ${ARGS[*]}"
out=$(bash "$MODULE" "${ARGS[@]}" </dev/null 2>&1); rc=$?
lines=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
log "rc=$rc lines=$lines"
printf '%s\n' "$out"
if [ "$rc" -eq 0 ]; then exit 0; else log "FAIL"; exit 1; fi
