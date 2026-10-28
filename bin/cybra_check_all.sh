#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/CYBRA"
P=0; F=0; U=0
ok(){ P=$((P+1)); printf "✅ %-30s %s\n" "$1" "$2"; }
no(){ F=$((F+1)); printf "❌ %-30s %s\n" "$1" "$2"; }
unk(){ U=$((U+1)); printf "⚠️  %-30s %s\n" "$1" "$2"; }

echo "═══ ПОВНА ПЕРЕВІРКА ═══"

D=$(grep -l '── git ──' modules/module_*/main.sh 2>/dev/null | wc -l)
N=$(grep -l '\\\\n' modules/module_*/main.sh 2>/dev/null | wc -l)
[ "$D" -eq 0 ] && ok "dashboard" "0" || no "dashboard" "$D"
[ "$N" -eq 0 ] && ok "\\n literal" "0" || no "\\n literal" "$N"

PCT=$(python3 -c "import json;print(json.load(open('state/snapshots/_master.json'))['pct'])" 2>/dev/null || echo 0)
[ "$(awk -v p="$PCT" 'BEGIN{print (p>=100)?1:0}')" = 1 ] && ok "state_100" "$PCT%" || no "state_100" "$PCT%"

ONLINE=$(pm2 jlist 2>/dev/null | python3 -c 'import sys,json;print(sum(1 for p in json.load(sys.stdin) if p["pm2_env"]["status"]=="online"))' 2>/dev/null)
[ "${ONLINE:-0}" -ge 8 ] && ok "PM2 online" "$ONLINE" || no "PM2 online" "$ONLINE"

pm2 jlist 2>/dev/null | grep -q cybra-rebuild-worker && ok "rebuild worker" "online" || no "rebuild worker" "missing"

B=$(bash modules/module_281_token_system/main.sh balance 0x74dA52028E42A37bc89E05c2fD5c52BE4CB48f 2>/dev/null | grep -oE ': [0-9]+\.?[0-9]*' | head -1 | tr -d ': ')
[ -n "$B" ] && ok "token balance" "$B CYBRA" || no "token balance" "?"

NT=$(redis-cli hlen cybra:nfc:tags 2>/dev/null || echo 0)
[ "$NT" -ge 1 ] && ok "NFC tags" "$NT" || no "NFC tags" "$NT"

NM=$(redis-cli hlen cybra:payment:methods 2>/dev/null || echo 0)
[ "$NM" -ge 1 ] && ok "payment methods" "$NM" || no "payment methods" "$NM"

PE=$(redis-cli get cybra:privacy:enabled 2>/dev/null || echo 0)
[ "$PE" = "1" ] && ok "privacy enabled" "1" || unk "privacy enabled" "$PE"

[ -f state/layers/permissions.json ] && ok "layers config" "exists" || no "layers config" "missing"

IC=$(python3 -c "import json;d=json.load(open('state/identity/registry.json'));print(sum(len(v) for v in d['registry'].values()))" 2>/dev/null || echo 0)
[ "$IC" -gt 100 ] && ok "identity registry" "$IC items" || no "identity registry" "$IC"

[ -f bin/cybra_exec_guarded.sh ] && ok "exec guard" "exists" || no "exec guard" "missing"

[ -f state/degrade_guard/baseline.json ] && ok "degrade baseline" "exists" || no "degrade baseline" "missing"

[ -f evo_evolution_handler.sh ] && ok "evo handler" "exists" || no "evo handler" "missing"

CYBRA_TASK_JSON='{"action":"check","name":"parliament"}' bash process_id_handler.sh 2>/dev/null | grep -q '"ok": true' && ok "process_id check" "works" || no "process_id check" "fails"

GS=$(git status --short | wc -l)
[ "$GS" -eq 0 ] && ok "git clean" "clean" || unk "git clean" "$GS changes"

LOCAL=$(git rev-parse HEAD 2>/dev/null | cut -c1-7)
REMOTE=$(git rev-parse origin/main 2>/dev/null | cut -c1-7)
[ "$LOCAL" = "$REMOTE" ] && ok "git push" "$LOCAL" || unk "git push" "local=$LOCAL remote=$REMOTE"

CF=$(ls modules/module_19_contract_tui_menu/contracts/*.json 2>/dev/null | wc -l)
[ "$CF" -gt 0 ] && ok "contracts" "$CF files" || no "contracts" "0"

curl -s -m 2 http://localhost:8000/api/health 2>/dev/null | grep -q '"status":"ok"' && ok "cybra-api" "healthy" || no "cybra-api" "down"

pm2 jlist 2>/dev/null | grep -q taxi-events && ok "taxi-events" "online" || no "taxi-events" "missing"

MISSING=""
for k in program_writer_task token_system_task process_id_task evo_evolution_task degrade_guard_task; do
  V=$(redis-cli HGET cybra:executor:mapping "$k" 2>/dev/null)
  [ -z "$V" ] && MISSING="$MISSING $k"
done
[ -z "$MISSING" ] && ok "mapping 5 types" "ok" || no "mapping" "missing:$MISSING"

echo
echo "═══ ✅$P  ❌$F  ⚠️$U ═══"
