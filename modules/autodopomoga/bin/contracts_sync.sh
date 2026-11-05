#!/data/data/com.termux/files/usr/bin/bash
# contracts_sync.sh — sync contracts.json with pm2 online processes
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CONTRACTS="$MOD/contracts.json"
RESERVED="god autowatch bg_dump autogit"

cp "$CONTRACTS" "$CONTRACTS.bak.$(date +%s)"

mapfile -t ONLINE < <(pm2 jlist 2>/dev/null | jq -r '.[] | select(.pm2_env.status=="online") | .name')

TMP=$(mktemp)
# базові 4 — зберегти як є
jq 'with_entries(select(.key == "god" or .key == "autowatch" or .key == "bg_dump" or .key == "autogit"))' \
   "$CONTRACTS" > "$TMP"

ADDED=()
for name in "${ONLINE[@]}"; do
    case " $RESERVED " in *" $name "*) continue ;; esac
    jq -e --arg n "$name" '.[$n]' "$TMP" >/dev/null 2>&1 && continue
    jq --arg n "$name" '.[$n] = {
        purpose: ("pm2 process: " + $n),
        weight: 1,
        health: ("pm2 jlist 2>/dev/null | jq -e '\''.[] | select(.name==\"" + $n + "\" and .pm2_env.status==\"online\")'\'' >/dev/null"),
        escalation: [
            {attempt: 1, actions: ["pm2 restart " + $n]},
            {attempt: 2, actions: ["pm2 resurrect", "pm2 save --force"]}
        ],
        max_attempts: 2,
        cooldown_sec: 600
    }' "$TMP" > "$TMP.new" && mv "$TMP.new" "$TMP"
    ADDED+=("$name")
done

# Прибрати контракти для процесів, яких більше нема в pm2 (крім reserved)
for comp in $(jq -r 'keys[]' "$TMP"); do
    case " $RESERVED " in *" $comp "*) continue ;; esac
    echo "${ONLINE[@]}" | grep -qw "$comp" || jq --arg c "$comp" 'del(.[$c])' "$TMP" > "$TMP.new" && mv "$TMP.new" "$TMP"
done

mv "$TMP" "$CONTRACTS"
jq . "$CONTRACTS" >/dev/null || { echo "❌ invalid json"; exit 1; }

echo "✅ contracts synced"
echo "   reserved: god, autowatch, bg_dump, autogit"
echo "   pm2-online: ${#ONLINE[@]}"
echo "   added: ${#ADDED[@]}"
printf '   %s\n' "${ADDED[@]}" 2>/dev/null || true
echo ""
echo "── verify ──"
"$MOD/bin/verify.sh" | jq .
