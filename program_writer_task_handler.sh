#!/data/data/com.termux/files/usr/bin/bash
# program_writer_task_handler.sh — генерує модуль через binmix (без AI)
set -euo pipefail
cd "$HOME/CYBRA"

PROG=$(printf '%s' "${CYBRA_TASK_JSON:-{\}}" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("prog","a"))')
case "$PROG" in
  a) N=300; NAME=my_program_a; CAT=custom ;;
  b) N=301; NAME=my_program_b; CAT=custom ;;
  *) echo '{"ok":false,"error":"bad prog"}'; exit 1 ;;
esac

# Генерація через binmix (не AI)
OUT=$(bash bin/cybra_binmix_base.sh "$N" "$NAME" "$CAT" 2>&1)

# binmix_base сам створює modules/module_NNN_NAME/main.sh + controllers/
MAIN=$(printf '%s' "$OUT" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("main",""))' 2>/dev/null || echo "")

if [ -z "$MAIN" ] || [ ! -f "$MAIN" ]; then
  echo '{"ok":false,"error":"binmix_base failed","raw":"'"$(printf '%s' "$OUT" | head -c 200 | tr -d "\n")"'"}'
  exit 1
fi

# копія в programs/prog_X/ для sync
mkdir -p "programs/prog_${PROG}"
cp "$MAIN" "programs/prog_${PROG}/main.sh"

BYTES=$(wc -c < "$MAIN")
printf '{"ok":true,"prog":"%s","backend":"binmix","n":%d,"main":"%s","bytes":%s}\n' \
  "$PROG" "$N" "$MAIN" "$BYTES"
