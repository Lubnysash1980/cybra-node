#!/data/data/com.termux/files/usr/bin/bash
# repair.sh <component> <attempt> — execute escalation actions from contract.
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
CONTRACTS="$MOD/contracts.json"
export CYBRA

COMP="${1:-}"; ATTEMPT="${2:-1}"
[ -z "$COMP" ] && { echo "usage: repair.sh <component> <attempt>"; exit 1; }

PURPOSE=$(jq -r --arg c "$COMP" '.[$c].purpose // "no purpose"' "$CONTRACTS")
ACTIONS=$(jq -r --arg c "$COMP" --argjson n "$ATTEMPT" \
    '.[$c].escalation[] | select(.attempt==$n) | .actions[]' "$CONTRACTS" 2>/dev/null)

[ -z "$ACTIONS" ] && { echo "no escalation level $ATTEMPT for $COMP"; exit 1; }

echo "── repair $COMP (attempt $ATTEMPT) — purpose: $PURPOSE ──"
while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    echo "  exec: $cmd"
    bash -c "$cmd" 2>&1 | sed 's/^/    /'
    RC=$?
    [ "$RC" -ne 0 ] && echo "    ⚠ rc=$RC"
done <<< "$ACTIONS"
echo "  done"
