#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
STATE="$MOD/state"; mkdir -p "$STATE"
PIDFILE="$CYBRA/.cache/stats.pid"
LOG="$CYBRA/logs/stats.log"
mkdir -p "$CYBRA/.cache" "$CYBRA/logs"
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

if [ -f "$PIDFILE" ]; then
    OLD=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null && { log "already running pid=$OLD"; exit 0; }
    rm -f "$PIDFILE"
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

INTERVAL="${INTERVAL:-300}"
log "═══ STATS START ═══ pid=$$ interval=${INTERVAL}s"

while true; do
    "$MOD/bin/collect.sh" >/dev/null 2>&1
    "$MOD/bin/analyze.sh" >/dev/null 2>&1
    log "tick ok anomalies=$(jq -r '.count // 0' "$STATE/anomalies.json" 2>/dev/null || echo 0)"
    sleep "$INTERVAL"
done
