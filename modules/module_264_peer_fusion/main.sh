#!/data/data/com.termux/files/usr/bin/bash
# module_264: peer_fusion (peer) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="peer_fusion"
MODULE_CAT="peer"

case "$ACTION" in
  resolve)
    RID="${1:-}"
    [ -z "$RID" ] && exit 1
    echo "════ ${MODULE_LABEL}: $RID ════"
    CONF=0
    echo "  ─── sources ───"
    CAM=$(redis-cli hget cybra:taxi:peer:discovered "$RID" 2>/dev/null)
    [ -n "$CAM" ] && { echo "  ✓ camera: $CAM"; CONF=$((CONF+40)); }
    CELL=$(redis-cli hget "cybra:taxi:peer:proximity:$RID" cell 2>/dev/null)
    [ -n "$CELL" ] && { echo "  ✓ cell: $CELL"; CONF=$((CONF+25)); }
    LOC=$(redis-cli hget cybra:taxi:location:last any 2>/dev/null)
    [ -n "$LOC" ] && { echo "  ✓ location: $LOC"; CONF=$((CONF+20)); }
    MANUAL=$(redis-cli hget "cybra:taxi:peer:manual:$RID" any 2>/dev/null)
    [ -n "$MANUAL" ] && { echo "  ✓ manual: $MANUAL"; CONF=$((CONF+15)); }
    echo "  ─── confidence: $CONF/100 ───"
    if [ "$CONF" -ge 40 ]; then
      redis-cli hset "cybra:taxi:peer:matched:$RID" "confidence" "$CONF" >/dev/null
      redis-cli hset "cybra:peer:matched:$RID" "confidence" "$CONF" >/dev/null
      echo "  ✅ MATCH (>=40%)"
    else
      echo "  ⚠️ low confidence — need camera QR or manual"
    fi
    ;;
  set-manual)
    RID="${1:-}"; LAT="${2:-}"; LON="${3:-}"
    [ -z "$RID" ] && exit 1
    redis-cli hset "cybra:taxi:peer:manual:$RID" any "$LAT,$LON,$(date -u +%FT%TZ)" >/dev/null
    echo "✅ manual peer marker: $RID @ $LAT,$LON"
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  peer fusion: resolve <ride> | set-manual <ride> <lat> <lon>"
    ;;
esac
