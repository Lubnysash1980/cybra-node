#!/data/data/com.termux/files/usr/bin/bash
# module_260: peer_camera (peer) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-show}"; shift $(( $# > 0 ? 1 : 0 ))

case "$ACTION" in
  make-qr)
    RID="${1:-}"
    [ -z "$RID" ] && { echo "usage: $0 make-qr <ride_id>"; exit 1; }
    PAYLOAD="cybra:ride:$RID:$(date +%s)"
    OUT="$CYBRA/evidence/qr_${RID}.png"
    mkdir -p "$CYBRA/evidence"

    # Python qrcode
    if python3 -c "import qrcode" 2>/dev/null; then
      python3 -c "
import qrcode
img = qrcode.make('$PAYLOAD')
img.save('$OUT')
print('✅ saved: $OUT')
" || { echo "❌ qrcode failed"; exit 1; }
    elif command -v qrencode >/dev/null 2>&1; then
      qrencode -o "$OUT" "$PAYLOAD" && echo "✅ saved: $OUT"
    else
      echo "❌ no QR tool:"
      echo "   pip install qrcode[pil]"
      echo "   або: pkg install libqrencode (якщо є)"
      exit 1
    fi

    redis-cli hset cybra:taxi:peer:qr "$RID" "$PAYLOAD" >/dev/null
    echo "   payload: $PAYLOAD"
    ;;
  scan)
    OUT="$CYBRA/evidence/scan_$(date +%s).jpg"
    mkdir -p "$CYBRA/evidence"
    if ! command -v termux-camera-photo >/dev/null 2>&1; then
      echo "❌ termux-api missing"
      echo "   pkg install termux-api"
      echo "   + встановити Termux:API з F-Droid"
      exit 1
    fi
    if ! command -v zbarimg >/dev/null 2>&1; then
      echo "❌ zbarimg missing: pkg install zbar"
      exit 1
    fi
    termux-camera-photo -c 0 "$OUT" 2>/dev/null
    [ -f "$OUT" ] || { echo "❌ photo fail"; exit 1; }
    PAYLOAD=$(zbarimg -q --raw "$OUT" 2>/dev/null | head -1)
    [ -z "$PAYLOAD" ] && { echo "❌ no QR in photo"; exit 1; }
    echo "📷 scanned: $PAYLOAD"
    case "$PAYLOAD" in
      cybra:ride:*)
        RID=$(printf '%s' "$PAYLOAD" | cut -d: -f3)
        redis-cli hset cybra:taxi:peer:discovered "$RID" "camera|$(date -u +%FT%TZ)" >/dev/null
        echo "✅ peer found WITHOUT GPS: ride=$RID"
        ;;
      *) echo "⚠️ unrecognized payload"; ;;
    esac
    ;;
  show|*)
    echo "════ peer_camera ════"
    echo "  ─── QR registry ───"
    redis-cli hgetall cybra:taxi:peer:qr 2>/dev/null | paste - -
    echo "  ─── discovered ───"
    redis-cli hgetall cybra:taxi:peer:discovered 2>/dev/null | paste - -
    echo "  hint: $0 make-qr <ride> | scan"
    ;;
esac
