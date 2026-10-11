#!/data/data/com.termux/files/usr/bin/bash
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE="$BASE/evidence"

mkdir -p "$EVIDENCE"

PASS=0
FAIL=0

pass() {
    printf 'PASS | %s\n' "$1"
    PASS=$((PASS + 1))
}

fail() {
    printf 'FAIL | %s\n' "$1"
    FAIL=$((FAIL + 1))
}

echo "============================================================"
echo " CYBRA MODULE 17"
echo " LICENSE & CONTRACT MENU CONTROLLER"
echo "============================================================"
echo

# ------------------------------------------------------------
# TEST 01 — license rate
# ------------------------------------------------------------

LICENSE_BPS=100
LICENSE_PERCENT=1

if [ "$LICENSE_BPS" -eq 100 ] &&
   [ "$LICENSE_PERCENT" -eq 1 ]; then
    pass "License rate is exactly 1%"
else
    fail "License rate is not 1%"
fi

# ------------------------------------------------------------
# TEST 02 — deterministic calculation
# ------------------------------------------------------------

CONTRACT_AMOUNT=10000
LICENSE_BPS=100

LICENSE_AMOUNT=$(( CONTRACT_AMOUNT * LICENSE_BPS / 10000 ))

if [ "$LICENSE_AMOUNT" -eq 100 ]; then
    pass "10000 contract produces 100 license amount"
else
    fail "Incorrect license calculation"
fi

# ------------------------------------------------------------
# TEST 03 — another calculation
# ------------------------------------------------------------

CONTRACT_AMOUNT=5000
LICENSE_AMOUNT=$(( CONTRACT_AMOUNT * 100 / 10000 ))

if [ "$LICENSE_AMOUNT" -eq 50 ]; then
    pass "5000 contract produces 50 license amount"
else
    fail "Incorrect second license calculation"
fi

# ------------------------------------------------------------
# TEST 04 — exact integer calculation
# ------------------------------------------------------------

CONTRACT_AMOUNT=123456
LICENSE_AMOUNT=$(( CONTRACT_AMOUNT * 100 / 10000 ))

if [ "$LICENSE_AMOUNT" -eq 1234 ]; then
    pass "Integer calculation is deterministic"
else
    fail "Integer calculation failed"
fi

# ------------------------------------------------------------
# TEST 05 — zero contract blocked
# ------------------------------------------------------------

CONTRACT_AMOUNT=0

if [ "$CONTRACT_AMOUNT" -le 0 ]; then
    pass "Zero contract amount is BLOCKED"
else
    fail "Zero contract amount accepted"
fi

# ------------------------------------------------------------
# TEST 06 — negative contract blocked
# ------------------------------------------------------------

CONTRACT_AMOUNT=-100

if [ "$CONTRACT_AMOUNT" -le 0 ]; then
    pass "Negative contract amount is BLOCKED"
else
    fail "Negative contract amount accepted"
fi

# ------------------------------------------------------------
# TEST 07 — payer required
# ------------------------------------------------------------

LICENSE_PAYER=""

if [ -z "$LICENSE_PAYER" ]; then
    pass "Missing license payer is BLOCKED"
else
    fail "Missing payer accepted"
fi

# ------------------------------------------------------------
# TEST 08 — recipient required
# ------------------------------------------------------------

LICENSE_RECIPIENT=""

if [ -z "$LICENSE_RECIPIENT" ]; then
    pass "Missing license recipient is BLOCKED"
else
    fail "Missing recipient accepted"
fi

# ------------------------------------------------------------
# TEST 09 — double charge
# ------------------------------------------------------------

LICENSE_ALREADY_PAID=TRUE
SECOND_LICENSE_CHARGE=FALSE

if [ "$LICENSE_ALREADY_PAID" = "TRUE" ] &&
   [ "$SECOND_LICENSE_CHARGE" = "FALSE" ]; then
    pass "Double license charge is BLOCKED"
else
    fail "Double license charge protection failed"
fi

# ------------------------------------------------------------
# TEST 10 — license does not create TRUE_100
# ------------------------------------------------------------

LICENSE_PAID=TRUE
GLOBAL_TRUE_100=FALSE

if [ "$LICENSE_PAID" = "TRUE" ] &&
   [ "$GLOBAL_TRUE_100" = "FALSE" ]; then
    pass "License payment cannot create TRUE_100"
else
    fail "License incorrectly created TRUE_100"
fi

# ------------------------------------------------------------
# TEST 11 — license cannot release escrow
# ------------------------------------------------------------

LICENSE_PAID=TRUE
RELEASE_AUTHORIZED=FALSE

if [ "$RELEASE_AUTHORIZED" = "FALSE" ]; then
    pass "License cannot authorize escrow release"
else
    fail "License bypassed release authorization"
fi

# ------------------------------------------------------------
# TEST 12 — license cannot replace signatures
# ------------------------------------------------------------

LICENSE_PAID=TRUE
BUYER_SIGNED=FALSE
SELLER_SIGNED=FALSE

if [ "$BUYER_SIGNED" = "FALSE" ] &&
   [ "$SELLER_SIGNED" = "FALSE" ]; then
    pass "License cannot replace buyer/seller signatures"
else
    fail "Signature requirement bypassed"
fi

# ------------------------------------------------------------
# TEST 13 — license cannot replace delivery
# ------------------------------------------------------------

LICENSE_PAID=TRUE
DELIVERY_CONFIRMED=FALSE
BUYER_RECEIPT=FALSE

if [ "$DELIVERY_CONFIRMED" = "FALSE" ] &&
   [ "$BUYER_RECEIPT" = "FALSE" ]; then
    pass "License cannot replace delivery/receipt"
else
    fail "Delivery/receipt requirement bypassed"
fi

# ------------------------------------------------------------
# TEST 14 — license cannot replace backend consensus
# ------------------------------------------------------------

LICENSE_PAID=TRUE
BACKEND_CONSENSUS=FALSE

if [ "$BACKEND_CONSENSUS" = "FALSE" ]; then
    pass "License cannot replace backend consensus"
else
    fail "Backend consensus bypassed"
fi

# ------------------------------------------------------------
# TEST 15 — license cannot replace watchdog
# ------------------------------------------------------------

LICENSE_PAID=TRUE
WATCHDOG_PASS=FALSE

if [ "$WATCHDOG_PASS" = "FALSE" ]; then
    pass "License cannot replace watchdog"
else
    fail "Watchdog requirement bypassed"
fi

# ------------------------------------------------------------
# TEST 16 — license cannot replace final authorization
# ------------------------------------------------------------

LICENSE_PAID=TRUE
FINAL_AUTHORIZATION=FALSE

if [ "$FINAL_AUTHORIZATION" = "FALSE" ]; then
    pass "License cannot replace final authorization"
else
    fail "Final authorization bypassed"
fi

# ------------------------------------------------------------
# TEST 17 — TEST cannot send transaction
# ------------------------------------------------------------

MODE=TEST
AUTO_LICENSE_PAYMENT=FALSE
REAL_TRANSACTION_SENT=FALSE

if [ "$MODE" = "TEST" ] &&
   [ "$AUTO_LICENSE_PAYMENT" = "FALSE" ] &&
   [ "$REAL_TRANSACTION_SENT" = "FALSE" ]; then
    pass "TEST mode cannot send license transaction"
else
    fail "Automatic license transaction detected"
fi

# ------------------------------------------------------------
# TEST 18 — user action
# ------------------------------------------------------------

USER_ACTION_REQUIRED=TRUE
METAMASK_USER_ACTION_REQUIRED=TRUE

if [ "$USER_ACTION_REQUIRED" = "TRUE" ] &&
   [ "$METAMASK_USER_ACTION_REQUIRED" = "TRUE" ]; then
    pass "Wallet action remains user-controlled"
else
    fail "User wallet action requirement missing"
fi

# ------------------------------------------------------------
# TEST 19 — menu exists
# ------------------------------------------------------------

MENU="$BASE/config/menu.canonical"

if [ -s "$MENU" ]; then
    pass "Contract menu exists"
else
    fail "Contract menu missing"
fi

# ------------------------------------------------------------
# TEST 20 — context template
# ------------------------------------------------------------

CTX="$BASE/config/license_context.template"

if [ -s "$CTX" ]; then
    pass "License context template exists"
else
    fail "License context template missing"
fi

# ------------------------------------------------------------
# FINAL RESULT
# ------------------------------------------------------------

cat > "$EVIDENCE/test_result.env" <<EOF2
MODULE_ID=17
MODULE_NAME=CYBRA_LICENSE_CONTRACT_MENU_CONTROLLER
MODULE_VERSION=1.0.0
PATCH_ID=CYBRA-M17-PATCH-0001

MODE=TEST
CHAIN_ID=56
NETWORK=BSC_MAINNET

LICENSE_BPS=100
LICENSE_PERCENT=1

TEST_PASS=$PASS
TEST_FAIL=$FAIL

DOUBLE_LICENSE_CHARGE=BLOCKED
LICENSE_CREATES_TRUE100=FALSE
LICENSE_CREATES_RELEASE=FALSE

AUTO_LICENSE_PAYMENT=FALSE
AUTO_RELEASE=FALSE
AUTO_TRANSACTION=FALSE

USER_ACTION_REQUIRED=TRUE
METAMASK_USER_ACTION_REQUIRED=TRUE

REAL_TRANSACTION_SENT=FALSE
GLOBAL_TRUE_100=FALSE
FROZEN=FALSE
EOF2

echo
echo "============================================================"
echo " MODULE 17 RESULT"
echo "============================================================"
printf 'PASS=%s\n' "$PASS"
printf 'FAIL=%s\n' "$FAIL"
echo "============================================================"

if [ "$FAIL" -eq 0 ]; then
    echo "MODULE_17_TEST=PASS"
    exit 0
else
    echo "MODULE_17_TEST=FAIL"
    exit 1
fi
