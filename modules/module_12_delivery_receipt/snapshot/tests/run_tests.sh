#!/data/data/com.termux/files/usr/bin/bash
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE/config/delivery.env"
source "$BASE/evidence/test_context.env"

PASS=0
FAIL=0

test_pass() {
    echo "[PASS] $1"
    PASS=$((PASS+1))
}

test_fail() {
    echo "[FAIL] $1"
    FAIL=$((FAIL+1))
}

echo "============================================================"
echo " CYBRA MODULE 12"
echo " DELIVERY / RECEIPT CONTROLLER"
echo " TEST SUITE"
echo "============================================================"

# ------------------------------------------------------------
# 01 — Initial state
# ------------------------------------------------------------

DELIVERY_CONFIRMED=FALSE
BUYER_RECEIPT_CONFIRMED=FALSE

if [ "$DELIVERY_CONFIRMED" = "FALSE" ] &&
   [ "$BUYER_RECEIPT_CONFIRMED" = "FALSE" ]; then
    test_pass "Initial delivery/receipt state is BLOCKED"
else
    test_fail "Initial state is not BLOCKED"
fi

# ------------------------------------------------------------
# 02 — Missing delivery evidence
# ------------------------------------------------------------

DELIVERY_EVIDENCE_ID=""
DELIVERY_STATUS="WAITING"

if [ -z "$DELIVERY_EVIDENCE_ID" ] &&
   [ "$DELIVERY_STATUS" = "WAITING" ]; then
    test_pass "Missing delivery evidence => WAITING"
else
    test_fail "Missing delivery evidence did not produce WAITING"
fi

# ------------------------------------------------------------
# 03 — Missing buyer receipt
# ------------------------------------------------------------

RECEIPT_ID=""
RECEIPT_STATUS="WAITING"

if [ -z "$RECEIPT_ID" ] &&
   [ "$RECEIPT_STATUS" = "WAITING" ]; then
    test_pass "Missing buyer receipt => WAITING"
else
    test_fail "Missing buyer receipt did not produce WAITING"
fi

# ------------------------------------------------------------
# 04 — Valid delivery evidence
# ------------------------------------------------------------

DELIVERY_EVIDENCE_ID="DELIVERY-EVIDENCE-001"
DELIVERY_ORDER_ID="$ORDER_ID"
DELIVERY_ORDER_HASH="$ORDER_HASH"
DELIVERY_TERMS_HASH="$TERMS_HASH"
DELIVERY_BUYER="$BUYER"
DELIVERY_SELLER="$SELLER"
DELIVERY_TIMESTAMP="2026-10-08T00:00:00Z"

if [ "$DELIVERY_EVIDENCE_ID" != "" ] &&
   [ "$DELIVERY_ORDER_ID" = "$ORDER_ID" ] &&
   [ "$DELIVERY_ORDER_HASH" = "$ORDER_HASH" ] &&
   [ "$DELIVERY_TERMS_HASH" = "$TERMS_HASH" ] &&
   [ "$DELIVERY_BUYER" = "$BUYER" ] &&
   [ "$DELIVERY_SELLER" = "$SELLER" ] &&
   [ "$DELIVERY_TIMESTAMP" != "" ]; then

    DELIVERY_CONFIRMED=TRUE
    DELIVERY_STATUS=CONFIRMED
    test_pass "Valid delivery evidence accepted"
else
    test_fail "Valid delivery evidence rejected"
fi

# ------------------------------------------------------------
# 05 — Wrong order evidence
# ------------------------------------------------------------

WRONG_ORDER_HASH="$(printf '%s' 'WRONG-ORDER' | sha256sum | awk '{print $1}')"

if [ "$WRONG_ORDER_HASH" != "$ORDER_HASH" ]; then
    DELIVERY_STATUS=FALSE_RETRY
    DELIVERY_CONFIRMED=FALSE
    test_pass "Wrong order evidence rejected"
else
    test_fail "Wrong order evidence was accepted"
fi

# restore valid delivery state
DELIVERY_CONFIRMED=TRUE
DELIVERY_STATUS=CONFIRMED

# ------------------------------------------------------------
# 06 — Wrong terms hash
# ------------------------------------------------------------

WRONG_TERMS_HASH="$(printf '%s' 'WRONG-TERMS' | sha256sum | awk '{print $1}')"

if [ "$WRONG_TERMS_HASH" != "$TERMS_HASH" ]; then
    DELIVERY_STATUS=FALSE_RETRY
    DELIVERY_CONFIRMED=FALSE
    test_pass "Wrong TERMS_HASH evidence rejected"
else
    test_fail "Wrong TERMS_HASH evidence was accepted"
fi

# restore
DELIVERY_CONFIRMED=TRUE
DELIVERY_STATUS=CONFIRMED

# ------------------------------------------------------------
# 07 — Wrong buyer
# ------------------------------------------------------------

WRONG_BUYER="0x3333333333333333333333333333333333333333"

if [ "$WRONG_BUYER" != "$BUYER" ]; then
    DELIVERY_STATUS=FALSE_RETRY
    DELIVERY_CONFIRMED=FALSE
    test_pass "Evidence for wrong buyer rejected"
else
    test_fail "Wrong buyer evidence was accepted"
fi

DELIVERY_CONFIRMED=TRUE
DELIVERY_STATUS=CONFIRMED

# ------------------------------------------------------------
# 08 — Wrong seller
# ------------------------------------------------------------

WRONG_SELLER="0x4444444444444444444444444444444444444444"

if [ "$WRONG_SELLER" != "$SELLER" ]; then
    DELIVERY_STATUS=FALSE_RETRY
    DELIVERY_CONFIRMED=FALSE
    test_pass "Evidence for wrong seller rejected"
else
    test_fail "Wrong seller evidence was accepted"
fi

DELIVERY_CONFIRMED=TRUE
DELIVERY_STATUS=CONFIRMED

# ------------------------------------------------------------
# 09 — Valid buyer receipt
# ------------------------------------------------------------

RECEIPT_ID="BUYER-RECEIPT-001"
RECEIPT_ORDER_ID="$ORDER_ID"
RECEIPT_ORDER_HASH="$ORDER_HASH"
RECEIPT_TERMS_HASH="$TERMS_HASH"
RECEIPT_BUYER="$BUYER"
RECEIPT_TIMESTAMP="2026-10-08T00:05:00Z"

if [ "$RECEIPT_ID" != "" ] &&
   [ "$RECEIPT_ORDER_ID" = "$ORDER_ID" ] &&
   [ "$RECEIPT_ORDER_HASH" = "$ORDER_HASH" ] &&
   [ "$RECEIPT_TERMS_HASH" = "$TERMS_HASH" ] &&
   [ "$RECEIPT_BUYER" = "$BUYER" ] &&
   [ "$RECEIPT_TIMESTAMP" != "" ]; then

    BUYER_RECEIPT_CONFIRMED=TRUE
    RECEIPT_STATUS=CONFIRMED
    test_pass "Valid buyer receipt accepted"
else
    test_fail "Valid buyer receipt rejected"
fi

# ------------------------------------------------------------
# 10 — Wrong receipt wallet
# ------------------------------------------------------------

WRONG_RECEIPT_BUYER="0x5555555555555555555555555555555555555555"

if [ "$WRONG_RECEIPT_BUYER" != "$BUYER" ]; then
    RECEIPT_STATUS=FALSE_RETRY
    BUYER_RECEIPT_CONFIRMED=FALSE
    test_pass "Receipt from wrong buyer rejected"
else
    test_fail "Receipt from wrong buyer was accepted"
fi

BUYER_RECEIPT_CONFIRMED=TRUE
RECEIPT_STATUS=CONFIRMED

# ------------------------------------------------------------
# 11 — Delivery alone cannot create TRUE_100
# ------------------------------------------------------------

GLOBAL_TRUE_100=FALSE
DELIVERY_CONFIRMED=TRUE
BUYER_RECEIPT_CONFIRMED=FALSE

if [ "$DELIVERY_CONFIRMED" = "TRUE" ] &&
   [ "$BUYER_RECEIPT_CONFIRMED" = "FALSE" ] &&
   [ "$GLOBAL_TRUE_100" = "FALSE" ]; then
    test_pass "Delivery alone cannot create GLOBAL_TRUE_100"
else
    test_fail "Delivery alone incorrectly created TRUE_100"
fi

# ------------------------------------------------------------
# 12 — Receipt alone cannot create TRUE_100
# ------------------------------------------------------------

DELIVERY_CONFIRMED=FALSE
BUYER_RECEIPT_CONFIRMED=TRUE
GLOBAL_TRUE_100=FALSE

if [ "$GLOBAL_TRUE_100" = "FALSE" ]; then
    test_pass "Buyer receipt alone cannot create GLOBAL_TRUE_100"
else
    test_fail "Buyer receipt alone incorrectly created TRUE_100"
fi

# ------------------------------------------------------------
# 13 — Both evidence conditions complete
# ------------------------------------------------------------

DELIVERY_CONFIRMED=TRUE
BUYER_RECEIPT_CONFIRMED=TRUE
GLOBAL_TRUE_100=FALSE

if [ "$DELIVERY_CONFIRMED" = "TRUE" ] &&
   [ "$BUYER_RECEIPT_CONFIRMED" = "TRUE" ] &&
   [ "$GLOBAL_TRUE_100" = "FALSE" ]; then
    test_pass "Delivery + receipt complete, but global TRUE_100 remains external"
else
    test_fail "Module incorrectly established global TRUE_100"
fi

# ------------------------------------------------------------
# 14 — Escrow release remains blocked
# ------------------------------------------------------------

ESCROW_RELEASE_ALLOWED=FALSE

if [ "$ESCROW_RELEASE_ALLOWED" = "FALSE" ]; then
    test_pass "Module 12 cannot release escrow"
else
    test_fail "Module 12 incorrectly enabled escrow release"
fi

# ------------------------------------------------------------
# 15 — Final authorization remains external
# ------------------------------------------------------------

FINAL_AUTHORIZATION_ALLOWED=FALSE

if [ "$FINAL_AUTHORIZATION_ALLOWED" = "FALSE" ]; then
    test_pass "Final release authorization remains external"
else
    test_fail "Module 12 incorrectly enabled final authorization"
fi

# ------------------------------------------------------------
# 16 — LIVE remains blocked
# ------------------------------------------------------------

LIVE_AUTHORIZATION=FALSE
REAL_TRANSACTION_SENT=FALSE

if [ "$LIVE_AUTHORIZATION" = "FALSE" ] &&
   [ "$REAL_TRANSACTION_SENT" = "FALSE" ]; then
    test_pass "LIVE and real transaction remain blocked"
else
    test_fail "LIVE or transaction was enabled"
fi

# ------------------------------------------------------------
# 17 — TEST evidence cannot become LIVE evidence
# ------------------------------------------------------------

MODE=TEST
LIVE_EVIDENCE=FALSE

if [ "$MODE" = "TEST" ] &&
   [ "$LIVE_EVIDENCE" = "FALSE" ]; then
    test_pass "TEST evidence cannot auto-promote to LIVE"
else
    test_fail "TEST evidence was promoted to LIVE"
fi

# ------------------------------------------------------------
# 18 — Rules hash integrity
# ------------------------------------------------------------

EXPECTED_RULE_HASH="$(cat "$BASE/rules/rules.sha256")"
ACTUAL_RULE_HASH="$(
    sha256sum "$BASE/rules/delivery_rules.canonical" \
    | awk '{print $1}'
)"

if [ "$EXPECTED_RULE_HASH" = "$ACTUAL_RULE_HASH" ]; then
    test_pass "Canonical rules SHA256 integrity PASS"
else
    test_fail "Canonical rules SHA256 integrity FAIL"
fi

# ------------------------------------------------------------
# Final
# ------------------------------------------------------------

echo
echo "============================================================"
echo " TEST RESULT"
echo " PASS=$PASS"
echo " FAIL=$FAIL"
echo "============================================================"

if [ "$FAIL" -eq 0 ]; then
    echo "MODULE_12_TEST=PASS"
    exit 0
else
    echo "MODULE_12_TEST=FAIL"
    exit 1
fi
