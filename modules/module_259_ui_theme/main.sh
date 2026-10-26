#!/data/data/com.termux/files/usr/bin/bash
# module_259: ui_theme (ui) — taxi_premium
# generated 2026-10-25T23:07:35Z
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-show}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="ui_theme"
MODULE_CAT="ui"

case "$ACTION" in
  set)
    NAME="${1:-bright}"
    redis-cli set "cybra:taxi:ui:theme" "$NAME" >/dev/null
    echo "🎨 theme: $NAME"
    ;;
  show|*)
    echo "════ ${MODULE_LABEL} ════"
    echo "  current: $(redis-cli get cybra:taxi:ui:theme 2>/dev/null || echo default)"
    echo "  hint: $0 set <bright|neon|sunset>"
    ;;
esac
