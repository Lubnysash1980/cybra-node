#!/data/data/com.termux/files/usr/bin/bash
# module_268: voice (voice) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-listen}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="voice"
MODULE_CAT="voice"

case "$ACTION" in
  listen)
    if command -v termux-speech-to-text >/dev/null 2>&1; then
      echo "🎤 listening..."
      TXT=$(timeout 10 termux-speech-to-text 2>/dev/null)
      [ -n "$TXT" ] && { echo "  heard: $TXT"; redis-cli set cybra:taxi:voice:last "$TXT" >/dev/null; }
    else
      echo "❌ termux-api missing (pkg install termux-api + app)"
    fi
    ;;
  say)
    TXT="${1:-}"
    [ -z "$TXT" ] && exit 1
    command -v termux-tts-speak >/dev/null 2>&1 && termux-tts-speak "$TXT" && echo "🔊 said: $TXT"
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 listen | say <text>"
    ;;
esac
