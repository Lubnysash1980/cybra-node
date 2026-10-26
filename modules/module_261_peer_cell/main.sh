#!/data/data/com.termux/files/usr/bin/bash
# module_261: peer_cell (peer) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="peer_cell"
MODULE_CAT="peer"

case "$ACTION" in
  scan)
    if ! command -v termux-telephony-cellinfo >/dev/null 2>&1; then
      echo "❌ termux-api missing (pkg install termux-api + app)"
      echo "   fallback: manual marker"
      exit 1
    fi
    INFO=$(termux-telephony-cellinfo 2>/dev/null)
    [ -z "$INFO" ] && { echo "❌ no cell info (no SIM / airplane)"; exit 1; }
    # extract mcc, mnc, cid, lac
    M=$(echo "$INFO" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    if isinstance(d,list): d=d[0]
    print(f\"{d.get('mcc','?')},{d.get('mnc','?')},{d.get('cid','?')},{d.get('lac','?')}\")
except: print('?')
")
    redis-cli hset cybra:taxi:peer:cell "current" "$M|$(date -u +%FT%TZ)" >/dev/null
    echo "📡 cell tower: $M  (GPS-free location fix)"
    ;;
  match)
    RID="${1:-}"
    [ -z "$RID" ] && exit 1
    MY=$(redis-cli hget cybra:taxi:peer:cell current 2>/dev/null | cut -d'|' -f1)
    [ -z "$MY" ] && { echo "❌ run 'scan' first"; exit 1; }
    echo "════ ${MODULE_LABEL} ════"
    echo "  my cell: $MY"
    echo "  → if driver on same tower, they're within ~500m-2km"
    redis-cli hset "cybra:taxi:peer:proximity:$RID" "cell" "$MY" >/dev/null
    echo "✅ proximity claim saved: $RID @ cell $MY"
    ;;
  list|*)
    echo "════ ${MODULE_LABEL} ════"
    redis-cli hget cybra:taxi:peer:cell current 2>/dev/null
    echo "  hint: $0 scan | match <ride_id>"
    ;;
esac
