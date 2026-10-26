#!/data/data/com.termux/files/usr/bin/bash
# module_270: sos (safety) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="sos"
MODULE_CAT="safety"

case "$ACTION" in
  trigger)
    REASON="${1:-emergency}"
    TS=$(date -u +%FT%TZ)
    LOC=$(redis-cli hget cybra:taxi:location:last any 2>/dev/null | cut -d'|' -f1,2)
    redis-cli rpush cybra:taxi:sos "{\"ts\":\"$TS\",\"reason\":\"$REASON\",\"loc\":\"$LOC\"}" >/dev/null
    redis-cli rpush cybra:parliament:queue "{\"id\":\"sos-$TS\",\"action\":\"sos_alert\",\"topic\":\"taxi_sos\",\"reason\":\"$REASON\",\"loc\":\"$LOC\",\"ts\":\"$TS\"}" >/dev/null
    echo "🚨 SOS TRIGGERED"
    echo "   reason: $REASON"
    echo "   location: $LOC"
    echo "   sent to parliament + parliament:queue"
    ;;
  list)
    echo "════ SOS history ════"
    redis-cli lrange cybra:taxi:sos 0 -1 2>/dev/null | tail -10
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 trigger [reason] | list"
    ;;
esac
