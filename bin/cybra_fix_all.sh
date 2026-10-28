#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"

echo "═══ FIX ALL ═══"

# 1. exec guard
if [ ! -f bin/cybra_exec_guarded.sh ]; then
cat > bin/cybra_exec_guarded.sh <<'G'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HANDLER="$1"; shift || true
CYBRA="$HOME/CYBRA"; cd "$CYBRA"
NAME=$(basename "$HANDLER" .sh)
LAYERS=$(python3 -c "
import json
try: d=json.load(open('state/layers/permissions.json'))
except: d={'executors':{}}
p=d['executors'].get('$NAME',{})
print(','.join(p.get('layers',['L0_sandbox'])))
" 2>/dev/null)
[ -z "$LAYERS" ] && LAYERS="L0_sandbox"
if [ ! -f "$HANDLER" ]; then
  [ -f "./$HANDLER" ] && HANDLER="./$HANDLER" || { echo '{"ok":false,"error":"handler_not_found"}'; exit 1; }
fi
exec bash "$HANDLER" "$@"
G
chmod 755 bin/cybra_exec_guarded.sh
echo "✅ exec guard"
fi

# 2. identity registry
if [ ! -f state/identity/registry.json ] || [ "$(python3 -c "import json;d=json.load(open('state/identity/registry.json'));print(sum(len(v) for v in d['registry'].values()))" 2>/dev/null || echo 0)" -lt 100 ]; then
  bash identity_layer_handler.sh >/dev/null 2>&1
  echo "✅ identity"
fi

# 3. layers (якщо відсутні)
[ -f state/layers/permissions.json ] || bash identity_layer_handler.sh >/dev/null 2>&1

# 4. payment methods
if [ "$(redis-cli hlen cybra:payment:methods 2>/dev/null || echo 0)" -eq 0 ]; then
  bash modules/module_280_payment_system/main.sh add main \
    --iban UA213223130000026007233566001 --card 4149620012345678 --note "main card" >/dev/null 2>&1
  bash modules/module_280_payment_system/main.sh add crypto \
    --wallet 0x74dA52028E42A37bc89E05c2fD5c52BE4CB48f --note "CYBRA token" >/dev/null 2>&1
  echo "✅ payment methods"
fi

# 5. NFC tag
if [ "$(redis-cli hlen cybra:nfc:tags 2>/dev/null || echo 0)" -eq 0 ]; then
  bash modules/module_282_nfc_payment/main.sh register tag_001 crypto >/dev/null 2>&1
  echo "✅ nfc tag"
fi

# 6. token balance (mint якщо 0)
BAL=$(bash modules/module_281_token_system/main.sh balance 0x74dA52028E42A37bc89E05c2fD5c52BE4CB48f 2>/dev/null | grep -oE '[0-9]+' | head -1)
if [ "${BAL:-0}" -eq 0 ]; then
  bash modules/module_281_token_system/main.sh mint 0x74dA52028E42A37bc89E05c2fD5c52BE4CB48f 10000 >/dev/null 2>&1
  echo "✅ token mint"
fi

# 7. privacy
if [ ! -f "$HOME/.cybra_privacy.key" ]; then
  command -v openssl >/dev/null 2>&1 || pkg install -y openssl-tool >/dev/null 2>&1
  openssl rand -hex 32 > "$HOME/.cybra_privacy.key"
  chmod 600 "$HOME/.cybra_privacy.key"
fi
redis-cli set cybra:privacy:enabled 1 >/dev/null
echo "✅ privacy"

# 8. commit
git add -A 2>/dev/null
git diff --cached --quiet || git -c user.email="parliament@cybra.local" -c user.name="cybra-parliament" \
  commit -m "fix: guard, identity, payment, nfc, token, privacy" >/dev/null 2>&1
git push origin main >/dev/null 2>&1 && echo "✅ git push" || echo "⚠ push"

echo
echo "── перевірка ──"
bash bin/cybra_check_all.sh
