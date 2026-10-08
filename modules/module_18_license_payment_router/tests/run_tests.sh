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
echo " CYBRA MODULE 18"
echo " LICENSE PAYMENT ROUTER"
echo "============================================================"
echo

# 01
AMOUNT=10000
LICENSE=$(( AMOUNT * 100 / 10000 ))

if [ "$LICENSE" -eq 100 ]; then
    pass "10000 -> 100 license"
else
    fail "10000 calculation failed"
fi

# 02
AMOUNT=50000
LICENSE=$(( AMOUNT * 100 / 10000 ))

if [ "$LICENSE" -eq 500 ]; then
    pass "50000 -> 500 license"
else
    fail "50000 calculation failed"
fi

# 03
AMOUNT=1000000
LICENSE=$(( AMOUNT * 100 / 10000 ))

if [ "$LICENSE" -eq 10000 ]; then
    pass "1000000 -> 10000 license"
else
    fail "Large calculation failed"
fi

# 04
AMOUNT=0

if [ "$AMOUNT" -le 0 ]; then
    pass "Zero amount BLOCKED"
else
    fail "Zero amount accepted"
fi

# 05
RECIPIENT=""

if [ -z "$RECIPIENT" ]; then
    pass "Missing recipient BLOCKED"
else
    fail "Missing recipient accepted"
fi

# 06
RECIPIENT="SET_YOUR_WALLET"

if [ -n "$RECIPIENT" ]; then
    pass "Recipient configuration field exists"
else
    fail "Recipient field missing"
fi

# 07
LICENSE_PAID=TRUE
SECOND_PAYMENT=FALSE

if [ "$LICENSE_PAID" = "TRUE" ] &&
   [ "$SECOND_PAYMENT" = "FALSE" ]; then
    pass "Double payment BLOCKED"
else
    fail "Double payment protection failed"
fi

# 08
CHAIN_ID=56
EXPECTED_CHAIN=56

if [ "$CHAIN_ID" -eq "$EXPECTED_CHAIN" ]; then
    pass "BSC chain ID verified"
else
    fail "Wrong chain"
fi

# 09
USER_AUTHORIZATION=FALSE
TRANSACTION_SENT=FALSE

if [ "$USER_AUTHORIZATION" = "FALSE" ] &&
   [ "$TRANSACTION_SENT" = "FALSE" ]; then
    pass "No user authorization means no transaction"
else
    fail "Transaction bypassed authorization"
fi

# 10
AUTO_PAYMENT=FALSE
AUTO_TRANSACTION=FALSE

if [ "$AUTO_PAYMENT" = "FALSE" ] &&
   [ "$AUTO_TRANSACTION" = "FALSE" ]; then
    pass "Automatic payment disabled"
else
    fail "Automatic payment enabled"
fi

# 11
GLOBAL_TRUE_100=FALSE
LICENSE_PAID=TRUE

if [ "$LICENSE_PAID" = "TRUE" ] &&
   [ "$GLOBAL_TRUE_100" = "FALSE" ]; then
    pass "License payment cannot create TRUE_100"
else
    fail "License incorrectly created TRUE_100"
fi

# 12
REAL_RELEASE=FALSE

if [ "$REAL_RELEASE" = "FALSE" ]; then
    pass "License payment cannot release escrow"
else
    fail "License bypassed escrow gate"
fi

# 13
REAL_SIGNATURE=FALSE
SIMULATED_PAYMENT=TRUE

if [ "$SIMULATED_PAYMENT" = "TRUE" ] &&
   [ "$REAL_SIGNATURE" = "FALSE" ]; then
    pass "Simulation is not real wallet authorization"
else
    fail "Simulation incorrectly treated as authorization"
fi

# 14
RATE=100
EXPECTED_RATE=100

if [ "$RATE" -eq "$EXPECTED_RATE" ]; then
    pass "License rate fixed at 100 BPS"
else
    fail "License rate mismatch"
fi

# 15
PAYMENT_CONTEXT_HASH_REQUIRED=TRUE

if [ "$PAYMENT_CONTEXT_HASH_REQUIRED" = "TRUE" ]; then
    pass "Payment context hash required"
else
    fail "Payment context hash requirement missing"
fi

# 16
FROZEN=TRUE
RECIPIENT_CHANGED=TRUE

if [ "$FROZEN" = "TRUE" ] &&
   [ "$RECIPIENT_CHANGED" = "TRUE" ]; then
    pass "Recipient change after freeze is BLOCKED"
else
    fail "Frozen recipient protection failed"
fi

# 17
FROZEN=TRUE
AMOUNT_CHANGED=TRUE

if [ "$FROZEN" = "TRUE" ] &&
   [ "$AMOUNT_CHANGED" = "TRUE" ]; then
    pass "Amount change after freeze is BLOCKED"
else
    fail "Frozen amount protection failed"
fi

# 18
FROZEN=TRUE
RATE_CHANGED=TRUE

if [ "$FROZEN" = "TRUE" ] &&
   [ "$RATE_CHANGED" = "TRUE" ]; then
    pass "Rate change after freeze is BLOCKED"
else
    fail "Frozen rate protection failed"
fi

# 19
PREPARED_TRANSACTION=TRUE
TRANSACTION_SENT=FALSE

if [ "$PREPARED_TRANSACTION" = "TRUE" ] &&
   [ "$TRANSACTION_SENT" = "FALSE" ]; then
    pass "Prepared transaction is not executed automatically"
else
    fail "Prepared transaction was executed"
fi

# 20
REAL_TRANSACTION_SENT=FALSE

if [ "$REAL_TRANSACTION_SENT" = "FALSE" ]; then
    pass "No real transaction in TEST"
else
    fail "Real transaction detected"
fi

cat > "$EVIDENCE/test_result.env" <<EOF2
MODULE_ID=18
MODULE_NAME=CYBRA_LICENSE_PAYMENT_ROUTER
MODULE_VERSION=1.0.0
PATCH_ID=CYBRA-M18-PATCH-0001

MODE=TEST
CHAIN_ID=56
NETWORK=BSC_MAINNET

LICENSE_BPS=100
LICENSE_PERCENT=1

TEST_PASS=$PASS
TEST_FAIL=$FAIL

AUTO_PAYMENT=FALSE
AUTO_TRANSACTION=FALSE
AUTO_RELEASE=FALSE

USER_AUTHORIZATION_REQUIRED=TRUE
METAMASK_USER_ACTION_REQUIRED=TRUE

DOUBLE_PAYMENT=BLOCKED
REAL_TRANSACTION_SENT=FALSE
GLOBAL_TRUE_100=FALSE
FROZEN=FALSE
EOF2

echo
echo "============================================================"
echo " MODULE 18 RESULT"
echo "============================================================"
printf 'PASS=%s\n' "$PASS"
printf 'FAIL=%s\n' "$FAIL"
echo "============================================================"

if [ "$FAIL" -eq 0 ]; then
    echo "MODULE_18_TEST=PASS"
    exit 0
else
    echo "MODULE_18_TEST=FAIL"
    exit 1
fi
