#!/data/data/com.termux/files/usr/bin/bash
set -u
<<<<<<< HEAD
MODULE="$1"; shift
LOG="$HOME/CYBRA/logs/taxi_ctrl_228.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
log "ctrl_228 args=$#"
[ -f "$MODULE" ] || { echo "❌ missing"; exit 2; }
bash -n "$MODULE" 2>/dev/null || { echo "❌ syntax"; exit 3; }
[ $# -gt 0 ] && ARGS=("$@") || ARGS=("list")
out=$(bash "$MODULE" "${ARGS[@]}" </dev/null 2>&1); rc=$?
log "rc=$rc"
printf '%s\n' "$out"
exit $rc
=======
M="$1"; shift
[ -f "$M" ] || { echo "❌ missing"; exit 2; }
bash -n "$M" 2>/dev/null || { echo "❌ syntax"; exit 3; }
[ $# -gt 0 ] && A=("$@") || A=("list")
bash "$M" "${A[@]}" </dev/null 2>&1; exit $?
>>>>>>> c0d6c45c7d164ae4ce146ebdd21942e9c1bda593
