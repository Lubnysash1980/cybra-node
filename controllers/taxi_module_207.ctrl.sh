#!/data/data/com.termux/files/usr/bin/bash
set -u
MODULE="$1"; shift
LOG="$HOME/CYBRA/logs/taxi_ctrl_207.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
log "ctrl_207 args=$#"
[ -f "$MODULE" ] || { echo "❌ missing"; exit 2; }
bash -n "$MODULE" 2>/dev/null || { echo "❌ syntax"; exit 3; }
[ $# -gt 0 ] && ARGS=("$@") || ARGS=("list")
out=$(bash "$MODULE" "${ARGS[@]}" </dev/null 2>&1); rc=$?
log "rc=$rc"
printf '%s\n' "$out"
exit $rc
