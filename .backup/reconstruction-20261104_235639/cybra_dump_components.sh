#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
MAP="$CYBRA/bin/cybra_components.json"
[ -f "$MAP" ] || { echo "no components map"; exit 1; }
TS=$(date '+%Y%m%d_%H%M%S'); BASE="$CYBRA/dumps/components"; mkdir -p "$BASE"
jq -r 'to_entries[] | "\(.key)\t\(.value|join(","))"' "$MAP" | while IFS=$'\t' read -r comp procs; do
  [ -z "$comp" ] && continue
  OUT="$BASE/comp_${comp}_${TS}"; mkdir -p "$OUT"
  if [ -n "$procs" ]; then
    for p in $(echo "$procs" | tr ',' ' '); do
      pm2 describe "$p" > "$OUT/pm2_${p}.txt" 2>&1
    done
  fi
  date '+%F %T' > "$OUT/timestamp"
  echo "comp $comp dumped"
done
ls -1dt "$BASE"/comp_*/ 2>/dev/null | tail -n +7 | xargs -r rm -rf
