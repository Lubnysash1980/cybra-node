#!/data/data/com.termux/files/usr/bin/bash
set -u
ROOT="$HOME/CYBRA"
PIDFILE="$ROOT/control/cybra_autobackup.pid"
LOG="$ROOT/logs/cybra_autobackup.log"
INTERVAL="${CYBRA_AUTOBACKUP_INTERVAL:-1800}"
mkdir -p "$ROOT/control" "$ROOT/logs"
log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

if [ -f "$PIDFILE" ]; then
    OLD=$(cat "$PIDFILE" 2>/dev/null || true)
    [ -n "$OLD" ] && [ "$OLD" != "$$" ] && kill -0 "$OLD" 2>/dev/null && exit 0
fi
echo "$$" > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT
log "autobackup started pid=$$ interval=${INTERVAL}s"
while true; do
    sleep "$INTERVAL"
    [ -x "$ROOT/cybra_backup_push.sh" ] && \
        { "$ROOT/cybra_backup_push.sh" >> "$LOG" 2>&1 && log "auto OK" || log "auto FAIL"; }
done
