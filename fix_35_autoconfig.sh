#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

CYBRA="$HOME/CYBRA"
MOD35="$CYBRA/modules/module_35_cybra_guardian"

echo "═══ 1. СТВОРЕННЯ config/ ДЛЯ MODULE_35 ═══"
mkdir -p "$MOD35/config"

cat > "$MOD35/config/guardian.env" <<'EOF'
MODULE_ID=35
MODULE_NAME=CYBRA_GUARDIAN
MODULE_VERSION=1.0.0
PATCH_ID=CYBRA-M35-PATCH-0001
MODE=TEST

GUARD_VAULT=REQUIRED
GUARD_REC=REQUIRED

HASH_ALGO=sha256
DEVICE_FP_REQUIRED=TRUE

IDENTITY_REQUIRED=TRUE
IDENTITY_FILE=identity.env
REGISTRY_LOG=registry.log

AUTO_RECOVERY=FALSE
REAL_TRANSACTION_SENT=FALSE
GLOBAL_TRUE_100=FALSE
EOF

echo "  [✓] config/guardian.env створено"

echo ""
echo "═══ 2. ПЕРЕВІРКА gd_verify У guardian.sh ═══"

if grep -q "^gd_verify()" "$MOD35/bin/guardian.sh"; then
    echo "  [✓] gd_verify існує"
    echo "  --- Вміст gd_verify ---"
    sed -n '/^gd_verify()/,/^}/p' "$MOD35/bin/guardian.sh"
else
    echo "  [!] gd_verify не знайдено — додаємо безпечну версію"

    cat >> "$MOD35/bin/guardian.sh" <<'GUARD_EOF'

# ============================================================
# Safe gd_verify (додано autoconfig, сумісне з set -u)
# ============================================================
gd_verify() {
    local name="${1:-}"
    local id="${2:-}"
    local wallet="${3:-}"
    local bio="${4:-none}"

    local vault="${GUARD_VAULT:-$HOME/CYBRA/modules/module_35_cybra_guardian/vault}"
    local id_file="$vault/identity.env"

    [ ! -f "$id_file" ] && return 1

    local stored_name stored_id stored_wallet
    stored_name="$(grep '^NAME=' "$id_file" 2>/dev/null | cut -d= -f2- || true)"
    stored_id="$(grep '^ID=' "$id_file" 2>/dev/null | cut -d= -f2- || true)"
    stored_wallet="$(grep '^WALLET=' "$id_file" 2>/dev/null | cut -d= -f2- || true)"

    [ "$name" = "$stored_name" ] || return 1
    [ "$id" = "$stored_id" ] || return 1
    [ "$wallet" = "$stored_wallet" ] || return 1

    return 0
}
GUARD_EOF

    echo "  [✓] gd_verify додано в guardian.sh"
fi

echo ""
echo "═══ 3. ПЕРЕВІРКА GUARD_VAULT У guardian.sh ═══"

if grep -q "GUARD_VAULT" "$MOD35/bin/guardian.sh"; then
    echo "  [✓] GUARD_VAULT згадується"
else
    echo "  [!] GUARD_VAULT не знайдено — додаємо fallback"
    cat >> "$MOD35/bin/guardian.sh" <<'VAULT_EOF'

# Fallback: якщо GUARD_VAULT не встановлено
GUARD_VAULT="${GUARD_VAULT:-$HOME/CYBRA/modules/module_35_cybra_guardian/vault}"
GUARD_REC="${GUARD_REC:-$HOME/CYBRA/modules/module_35_cybra_guardian/recovery}"
mkdir -p "$GUARD_VAULT" "$GUARD_REC"
VAULT_EOF
    echo "  [✓] GUARD_VAULT fallback додано"
fi

echo ""
echo "═══ 4. ЗАПУСК ТЕСТУ MODULE_35 ═══"
echo ""

cd "$MOD35" || exit 1

if [ ! -x "$MOD35/tests/run_tests.sh" ]; then
    chmod +x "$MOD35/tests/run_tests.sh"
fi

echo "--- Спроба 1: прямий запуск ---"
bash "$MOD35/tests/run_tests.sh" 2>&1 | tail -30 || {
    echo ""
    echo "--- Спроба 2: з fallback GUARD_VAULT ---"
    export GUARD_VAULT="$MOD35/vault"
    export GUARD_REC="$MOD35/recovery"
    bash "$MOD35/tests/run_tests.sh" 2>&1 | tail -30
}

echo ""
echo "═══ ГОТОВО ═══"
echo "Якщо тест пройшов — запусти повний hardening:"
echo "  ~/CYBRA/cybra_mega_hardening.sh"
