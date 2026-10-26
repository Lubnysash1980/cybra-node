#!/data/data/com.termux/files/usr/bin/bash
# module_267: i18n_loader (i18n) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="i18n_loader"
MODULE_CAT="i18n"

case "$ACTION" in
  set)
    LANG="${1:-en}"
    F="$CYBRA/state/taxi/i18n/$LANG.json"
    [ -f "$F" ] || { echo "❌ lang $LANG not found"; echo "  available: $(ls $CYBRA/state/taxi/i18n/ 2>/dev/null | sed 's/\.json//g' | tr '\n' ' ')"; exit 1; }
    redis-cli set cybra:taxi:i18n:lang "$LANG" >/dev/null
    echo "🌐 lang: $LANG"
    ;;
  get)
    KEY="${1:-welcome}"
    LANG=$(redis-cli get cybra:taxi:i18n:lang 2>/dev/null || echo en)
    F="$CYBRA/state/taxi/i18n/$LANG.json"
    V=$(python3 -c "import json;d=json.load(open('$F'));print(d.get('$KEY', '[' + '$KEY' + ' not found]'))" 2>/dev/null)
    echo "$V"
    ;;
  list)
    echo "════ langs ════"
    ls "$CYBRA/state/taxi/i18n/" 2>/dev/null | sed 's/\.json//g' | nl
    echo "  current: $(redis-cli get cybra:taxi:i18n:lang 2>/dev/null || echo en)"
    ;;
  dump)
    LANG=$(redis-cli get cybra:taxi:i18n:lang 2>/dev/null || echo en)
    F="$CYBRA/state/taxi/i18n/$LANG.json"
    cat "$F" | python3 -m json.tool
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 set <lang> | get <key> | list | dump"
    echo "  langs: en uk es de fr ar zh"
    ;;
esac
