#!/data/data/com.termux/files/usr/bin/bash
# verify.sh — compute deviation %. exit 0 if < 3%, exit 1 if >= 3%.
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
CONTRACTS="$MOD/contracts.json"
export CYBRA

TOTAL_W=0; BAD_W=0
HEALTHY=(); UNHEALTHY=()

for comp in $(jq -r 'keys[]' "$CONTRACTS"); do
    wgt=$(jq -r --arg c "$comp" '.[$c].weight' "$CONTRACTS")
    hc=$(jq -r --arg c "$comp" '.[$c].health' "$CONTRACTS")
    TOTAL_W=$((TOTAL_W + wgt))
    if bash -c "$hc" >/dev/null 2>&1; then
        HEALTHY+=("$comp")
    else
        UNHEALTHY+=("$comp")
        BAD_W=$((BAD_W + wgt))
    fi
done

DEV=$(awk -v b="$BAD_W" -v t="$TOTAL_W" 'BEGIN{ if(t==0){print "0.0"}else{printf "%.1f", b/t*100} }')

[ ${#HEALTHY[@]} -eq 0 ] && HJ="[]" || HJ=$(printf '%s\n' "${HEALTHY[@]}" | jq -R . | jq -s .)
[ ${#UNHEALTHY[@]} -eq 0 ] && UJ="[]" || UJ=$(printf '%s\n' "${UNHEALTHY[@]}" | jq -R . | jq -s .)

jq -n --argjson dev "$DEV" --argjson h "$HJ" --argjson u "$UJ" --argjson ts "$(date +%s)" \
    '{ts:$ts, deviation:$dev, healthy:$h, unhealthy:$u}'

awk -v d="$DEV" 'BEGIN{ exit !(d >= 3.0) }'
