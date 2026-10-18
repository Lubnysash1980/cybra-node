#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"

echo "═══ 1. ВИПРАВЛЕННЯ module_14_watchdog ═══"
MOD14="$CYBRA/modules/module_14_watchdog"
mkdir -p "$MOD14/config" "$MOD14/tests" "$MOD14/evidence" "$MOD14/snapshot"

cat > "$MOD14/config/watchdog.env" <<'EOF'
MODULE_ID=14
MODULE_NAME=WATCHDOG_SYSTEM_HEALTH_CONTROLLER
MODULE_VERSION=1.0.0
PATCH_ID=CYBRA-M14-PATCH-0001
MODE=TEST
CHAIN_ID=56
NETWORK=BSC_MAINNET

HEARTBEAT_REQUIRED=TRUE
PROCESS_HEALTH_REQUIRED=TRUE
REDIS_HEALTH_REQUIRED=TRUE
BACKEND_A_HEALTH_REQUIRED=TRUE
BACKEND_B_HEALTH_REQUIRED=TRUE
STATE_FRESHNESS_REQUIRED=TRUE

HEARTBEAT_MAX_AGE_SECONDS=60
STATE_MAX_AGE_SECONDS=300

REDIS_REQUIRED=TRUE
REDIS_HOST=127.0.0.1
REDIS_PORT=6379

BACKEND_A_REQUIRED=TRUE
BACKEND_B_REQUIRED=TRUE

STALE_STATE=FALSE
HEARTBEAT_OK=FALSE
REDIS_OK=FALSE
BACKEND_A_HEALTHY=FALSE
BACKEND_B_HEALTHY=FALSE
STATE_FRESH=FALSE

WATCHDOG_PASS=FALSE

HEALTH_STATUS=BLOCKED
FAILURE_ACTION=FALSE_RETRY
WAIT_ACTION=WAITING

GLOBAL_TRUE_100=FALSE
ESCROW_RELEASE_ALLOWED=FALSE
FINAL_AUTHORIZATION_ALLOWED=FALSE
LIVE_AUTHORIZATION=FALSE
REAL_TRANSACTION_SENT=FALSE

AUTO_RELEASE=FALSE
AUTO_SIGNATURE=FALSE
AUTO_LIVE=FALSE
EOF

echo "  [✓] module_14: config/watchdog.env створено"

echo ""
echo "═══ 2. ВИПРАВЛЕННЯ module_17_cybra_license_contract_menu ═══"
MOD17="$CYBRA/modules/module_17_cybra_license_contract_menu"
mkdir -p "$MOD17/config" "$MOD17/tests" "$MOD17/evidence" "$MOD17/snapshot" "$MOD17/rules"

cat > "$MOD17/config/menu.canonical" <<'EOF'
CYBRA CONTRACT MENU

Dashboard
Create Contract
Active Contracts
Buyer / Seller
Signatures
Escrow
Delivery / Receipt
Dual Backend
Watchdog
TRUE_100
Final Authorization
Release
Refund
Dispute
License
License Calculation
License Evidence
Audit
Snapshots
Frozen State
Contract Rules
EOF

cat > "$MOD17/config/license_context.template" <<'EOF'
CONTRACT_ID=REQUIRED
ORDER_HASH=REQUIRED
TERMS_HASH=REQUIRED
CHAIN_ID=56
CONTRACT_AMOUNT=REQUIRED
LICENSE_BPS=100
LICENSE_PERCENT=1
LICENSE_AMOUNT=CALCULATED
LICENSE_PAYER=REQUIRED
LICENSE_RECIPIENT=REQUIRED
EOF

echo "  [✓] module_17: config/menu.canonical + license_context.template створено"

echo ""
echo "═══ 3. ПЕРЕВІРКА module_35_cybra_guardian (чого не вистачає) ═══"
MOD35="$CYBRA/modules/module_35_cybra_guardian"

if [ -f "$MOD35/tests/run_tests.sh" ]; then
    echo "  --- Тест module_35 (перші 40 рядків) ---"
    head -40 "$MOD35/tests/run_tests.sh"
    echo ""
    echo "  --- Що є в module_35 ---"
    ls -la "$MOD35"
    echo ""
    echo "  --- Вміст tests/ ---"
    ls -la "$MOD35/tests"
else
    echo "  [!] module_35: tests/run_tests.sh не знайдено"
fi

echo ""
echo "═══ 4. ПЕРЕЗАПУСК ТЕСТІВ ═══"
echo ""
echo "--- module_14 ---"
bash "$MOD14/tests/run_tests.sh" 2>&1 | tail -15

echo ""
echo "--- module_17 ---"
bash "$MOD17/tests/run_tests.sh" 2>&1 | tail -15
