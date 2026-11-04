#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
PIDFILE="$CYBRA/.cache/parliament-auto.pid"
LOG="$CYBRA/logs/parliament-auto.log"
EVENTS="$MOD/state/.rollback-events.log"
LAST_PROP="$MOD/state/.last-auto-proposal.ts"
mkdir -p "$MOD/state" "$CYBRA/.cache" "$CYBRA/logs"
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

if [ -f "$PIDFILE" ]; then
  OLD=$(cat "$PIDFILE" 2>/dev/null)
  [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null && { log "already running pid=$OLD"; exit 0; }
  rm -f "$PIDFILE"
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

CHECK="${CHECK:-60}"; WINDOW="${WINDOW:-600}"
MIN_EVENTS="${MIN_EVENTS:-2}"; DEBOUNCE="${DEBOUNCE:-900}"
touch "$EVENTS" "$LAST_PROP"
log "═══ PROPOSE_AUTO START ═══ pid=$$ check=${CHECK}s window=${WINDOW}s min=${MIN_EVENTS} debounce=${DEBOUNCE}s"

while true; do
  NOW=$(date +%s)

  # 1) measure
  "$MOD/bin/measure.sh" >/dev/null 2>&1
  RC=$?
  if [ "$RC" -eq 1 ]; then
    echo "$NOW" >> "$EVENTS"
    log "ROLLBACK detected"
  fi

  # 2) prune old events
  CUTOFF=$((NOW - WINDOW))
  awk -v c="$CUTOFF" '$1 > c' "$EVENTS" > "$EVENTS.t" 2>/dev/null && mv "$EVENTS.t" "$EVENTS"

  CNT=$(wc -l < "$EVENTS" 2>/dev/null | tr -d ' ')
  CNT=${CNT:-0}

  if [ "$CNT" -ge "$MIN_EVENTS" ]; then
    LAST_TS=$(cat "$LAST_PROP" 2>/dev/null || echo 0)
    AGE=$((NOW - LAST_TS))
    if [ "$AGE" -lt "$DEBOUNCE" ]; then
      : # debounced
    elif cat "$MOD/state/proposals/"*.json 2>/dev/null | jq -r '.status' 2>/dev/null | grep -q '^pending$'; then
      log "skip propose: pending proposal exists"
    else
      log "PROPOSING: $CNT rollbacks in ${WINDOW}s → rollback to last dump"
      "$MOD/bin/parliament.sh" propose \
        --goal "chronic instability: $CNT rollbacks in ${WINDOW}s" \
        --exec "$MOD/bin/rollback.sh" >> "$LOG" 2>&1
      echo "$NOW" > "$LAST_PROP"
    fi
  fi

  sleep "$CHECK"
done
