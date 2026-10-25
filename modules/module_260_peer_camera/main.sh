#!/data/data/com.termux/files/usr/bin/bash
# module_260: peer_camera (peer) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-show}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="peer_camera"
MODULE_CAT="peer"

CONF="$CYBRA/state/taxi_premium_config.json"
case "$ACTION" in
  make-qr)
    RID="${1:-}"
    [ -z "$RID" ] && { echo "usage: $0 make-qr <ride_id>"; exit 1; }
    PAYLOAD="cybra:ride:$RID:$(date +%s)"
    OUT="$CYBRA/evidence/qr_${RID}.png"
    mkdir -p "$CYBRA/evidence"
    if command -v qrencode >/dev/null 2>&1; then
      qrencode -o "$OUT" "$PAYLOAD"
      redis-cli hset cybra:taxi:peer:qr "$RID" "$PAYLOAD" >/dev/null
      echo "✅ QR saved: $OUT"
      echo "   payload: $PAYLOAD"
    else
      echo "❌ qrencode missing: pkg install qrencode"
    fi
    ;;
  scan)
    OUT="$CYBRA/evidence/scan_$(date +%s).jpg"
    if ! command -v termux-camera-photo >/dev/null 2>&1; then
      echo "❌ pkg install termux-api + Termux:API app"; exit 1
    fi
    if ! command -v zbarimg >/dev/null 2>&1; then
      echo "❌ pkg install zbar"; exit 1
    fi
    termux-camera-photo -c 0 "$OUT" 2>/dev/null
    [ -f "$OUT" ] || { echo "❌ photo fail"; exit 1; }
    PAYLOAD=$(zbarimg -q --raw "$OUT" 2>/dev/null | head -1)
    [ -z "$PAYLOAD" ] && { echo "❌ no QR in photo"; exit 1; }
    echo "📷 scanned: $PAYLOAD"
    echo "$PAYLOAD" | grep -q '^cybra:ride:' && {
      RID=$(echo "$PAYLOAD" | cut -d: -f3)
      redis-cli hset cybra:taxi:peer:discovered "$RID" "camera|$(date -u +%FT%TZ)" >/dev/null
      echo "✅ peer found WITHOUT GPS: ride=$RID"
    }
    ;;
  show)
    echo "════ ${MODULE_LABEL} ════"
    redis-cli hgetall cybra:taxi:peer:qr 2>/dev/null | paste - -
    echo "  ─── discovered ───"
    redis-cli hgetall cybra:taxi:peer:discovered 2>/dev/null | paste - -
    echo "  hint: $0 make-qr <ride> | scan"
    ;;
  *) echo "usage: $0 make-qr <ride> | scan | show" ;;
esac
