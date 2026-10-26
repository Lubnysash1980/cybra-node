#!/data/data/com.termux/files/usr/bin/bash
# module_245: media_player (media) — taxi_premium
# generated 2026-10-25T23:07:35Z
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="media_player"
MODULE_CAT="media"

case "$ACTION" in
  record|start)
    DUR="${1:-10}"
    OUT="$CYBRA/evidence/video_$(date +%s).mp4"
    mkdir -p "$CYBRA/evidence"
    if command -v termux-camera-record >/dev/null 2>&1; then
      echo "🎥 recording ${DUR}s → $OUT"
      termux-camera-record -c 0 -d "$DUR" -o "$OUT" && ls -lh "$OUT" && echo "✅ saved"
    else
      echo "❌ termux-api not installed"
      echo "   pkg install termux-api  +  install Termux:API from F-Droid"
    fi
    ;;
  photo)
    OUT="$CYBRA/evidence/photo_$(date +%s).jpg"; mkdir -p "$CYBRA/evidence"
    if command -v termux-camera-photo >/dev/null 2>&1; then
      termux-camera-photo -c 0 "$OUT" && ls -lh "$OUT" && echo "✅ saved"
    else echo "❌ termux-api not installed"; fi
    ;;
  play)
    FILE="${1:-}"
    [ -z "$FILE" ] && { echo "usage: $0 play <file>"; exit 1; }
    if command -v termux-media-player >/dev/null 2>&1; then
      termux-media-player play "$FILE" && echo "▶ playing: $FILE"
    else echo "❌ termux-media-player missing (termux-api)"; fi
    ;;
  stop)
    command -v termux-media-player >/dev/null 2>&1 && termux-media-player stop 2>/dev/null
    echo "⏹ stopped"
    ;;
  list|*)
    echo "════ ${MODULE_LABEL} ════"
    echo "  media files in evidence/:"
    ls -lh "$CYBRA/evidence"/video_*.mp4 "$CYBRA/evidence"/photo_*.jpg 2>/dev/null | tail -10
    echo ""
    echo "  hint: $0 record [sec] | photo | play <file> | stop"
    ;;
esac
