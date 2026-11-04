#!/data/data/com.termux/files/usr/bin/bash
# cybra_dump_policy.sh — оцінка дампа: чи він 100%-переносний.
# Usage: cybra_dump_policy.sh <dump_dir>
# exit 0 = 100% (portable), exit 1 = not 100%
set -u
D="${1:-$HOME/CYBRA/dumps/latest}"
[ -d "$D" ] || { echo "no dump: $D"; exit 1; }
M="$D/MANIFEST.json"
[ -f "$M" ] || { echo "no MANIFEST.json"; exit 1; }

SCORE=$(jq -r '.score // 0' "$M")
STAGE=$(jq -r '.stage // 0' "$M")
ON=$(jq -r '.online // 0' "$M")
TOT=$(jq -r '.processes // 0' "$M")
ERR=$(jq -r '.errored // 0' "$M")
COLOR=$(jq -r '.color // "black"' "$M")

# 100% = stage 5 + всі online + 0 errored + color green
PORTABLE=false
[ "$STAGE" -ge 5 ] && [ "$ERR" -eq 0 ] && [ "$TOT" -gt 0 ] && [ "$ON" -eq "$TOT" ] && [ "$COLOR" = "green" ] && PORTABLE=true

echo "score=$SCORE stage=$STAGE ${ON}/${TOT}online ${ERR}err color=$COLOR portable=$PORTABLE"
[ "$PORTABLE" = "true" ] && exit 0 || exit 1
