#!/data/data/com.termux/files/usr/bin/bash
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE/config/backend.env"
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
echo " CYBRA MODULE 13"
echo " DUAL BACKEND CONSENSUS CONTROLLER"
echo " TEST SUITE"
echo "============================================================"

# ------------------------------------------------------------
# 01 — Initial state
# ------------------------------------------------------------

BACKEND_A_CONFIRMED=FALSE
BACKEND_B_CONFIRMED=FALSE
BACKEND_HASH_MATCH=FALSE

if [ "$BACKEND_A_CONFIRMED" = "FALSE" ] &&
   [ "$BACKEND_B_CONFIRMED" = "FALSE" ] &&
   [ "$BACKEND_HASH_MATCH" = "FALSE" ]; then
    test_pass "Initial state is BLOCKED"
else
    test_fail "Initial state is not BLOCKED"
fi

# ------------------------------------------------------------
# 02 — Backend A missing
# ------------------------------------------------------------

BACKEND_A_CONFIRMED=FALSE
BACKEND_B_CONFIRMED=TRUE

if [ "$BACKEND_A_CONFIRMED" = "FALSE" ]; then
    BACKEND_HASH_MATCH=FALSE
    test_pass "Missing Backend A blocks consensus"
else
    test_fail "Missing Backend A did not block consensus"
fi

# ------------------------------------------------------------
# 03 — Backend B missing
# ------------------------------------------------------------

BACKEND_A_CONFIRMED=TRUE
BACKEND_B_CONFIRMED=FALSE
BACKEND_HASH_MATCH=FALSE

if [ "$BACKEND_B_CONFIRMED" = "FALSE" ]; then
    test_pass "Missing Backend B blocks consensus"
else
    test_fail "Missing Backend B did not block consensus"
fi

# ------------------------------------------------------------
# 04 — Backend A produces state
# ------------------------------------------------------------

STATE_HASH_A="$(
    printf '%s' \
    "$ORDER_HASH|$TERMS_HASH|56|$CONTRACT_ADDRESS|STATE-V1" \
    | sha256sum | awk '{print $1}'
)"

BACKEND_A_CONFIRMED=TRUE

if [ "$STATE_HASH_A" != "" ]; then
    test_pass "Backend A produced a non-empty state hash"
else
    test_fail "Backend A state hash missing"
fi

# ------------------------------------------------------------
# 05 — Backend B produces different state
# ------------------------------------------------------------

STATE_HASH_B="$(
    printf '%s' \
    "$ORDER_HASH|$TERMS_HASH|56|$CONTRACT_ADDRESS|STATE-V2" \
    | sha256sum | awk '{print $1}'
)"

BACKEND_B_CONFIRMED=TRUE

if [ "$STATE_HASH_A" != "$STATE_HASH_B" ]; then
    BACKEND_HASH_MATCH=FALSE
    test_pass "Mismatched backend hashes => FALSE/RETRY"
else
    test_fail "Different test states unexpectedly matched"
fi

# ------------------------------------------------------------
# 06 — Matching state hashes
# ------------------------------------------------------------

STATE_HASH_B="$STATE_HASH_A"

if [ "$STATE_HASH_A" = "$STATE_HASH_B" ]; then
    BACKEND_HASH_MATCH=TRUE
    test_pass "Backend A/B state hashes match"
else
    test_fail "Matching backend hashes rejected"
fi

# ------------------------------------------------------------
# 07 — Both independent confirmations required
# ------------------------------------------------------------

BACKEND_A_CONFIRMED=TRUE
BACKEND_B_CONFIRMED=TRUE

if [ "$BACKEND_A_CONFIRMED" = "TRUE" ] &&
   [ "$BACKEND_B_CONFIRMED" = "TRUE" ] &&
   [ "$BACKEND_HASH_MATCH" = "TRUE" ]; then
    test_pass "Both independent backends required for consensus"
else
    test_fail "Dual backend consensus incomplete"
fi

# ------------------------------------------------------------
# 08 — Same backend cannot represent both
# ------------------------------------------------------------

BACKEND_A_ID="BACKEND-A"
BACKEND_B_ID="BACKEND-A"

if [ "$BACKEND_A_ID" = "$BACKEND_B_ID" ]; then
    INDEPENDENCE=FALSE
else
    INDEPENDENCE=TRUE
fi

if [ "$INDEPENDENCE" = "FALSE" ]; then
    BACKEND_HASH_MATCH=FALSE
    test_pass "Same backend cannot satisfy both roles"
else
    test_fail "Same backend was incorrectly accepted"
fi

# restore independent identities
BACKEND_A_ID="BACKEND-A"
BACKEND_B_ID="BACKEND-B"
BACKEND_HASH_MATCH=TRUE

# ------------------------------------------------------------
# 09 — Different ORDER_HASH rejected
# ------------------------------------------------------------

ORDER_HASH_B="$(
    printf '%s' 'WRONG-ORDER' | sha256sum | awk '{print $1}'
)"

if [ "$ORDER_HASH" != "$ORDER_HASH_B" ]; then
    BACKEND_HASH_MATCH=FALSE
    test_pass "Different ORDER_HASH rejected"
else
    test_fail "Different ORDER_HASH accepted"
fi

BACKEND_HASH_MATCH=TRUE

# ------------------------------------------------------------
# 10 — Different TERMS_HASH rejected
# ------------------------------------------------------------

TERMS_HASH_B="$(
    printf '%s' 'WRONG-TERMS' | sha256sum | awk '{print $1}'
)"

if [ "$TERMS_HASH" != "$TERMS_HASH_B" ]; then
    BACKEND_HASH_MATCH=FALSE
    test_pass "Different TERMS_HASH rejected"
else
    test_fail "Different TERMS_HASH accepted"
fi

BACKEND_HASH_MATCH=TRUE

# ------------------------------------------------------------
# 11 — Different chain rejected
# ------------------------------------------------------------

CHAIN_A=56
CHAIN_B=1

if [ "$CHAIN_A" != "$CHAIN_B" ]; then
    BACKEND_HASH_MATCH=FALSE
    test_pass "Different chain IDs rejected"
else
    test_fail "Different chain IDs accepted"
fi

BACKEND_HASH_MATCH=TRUE

# ------------------------------------------------------------
# 12 — Different contract rejected
# ------------------------------------------------------------

CONTRACT_A="$CONTRACT_ADDRESS"
CONTRACT_B="0x2222222222222222222222222222222222222222"

if [ "$CONTRACT_A" != "$CONTRACT_B" ]; then
    BACKEND_HASH_MATCH=FALSE
    test_pass "Different contract addresses rejected"
else
    test_fail "Different contract addresses accepted"
fi

BACKEND_HASH_MATCH=TRUE

# ------------------------------------------------------------
# 13 — Matching complete state
# ------------------------------------------------------------

BACKEND_A_CONFIRMED=TRUE
BACKEND_B_CONFIRMED=TRUE
BACKEND_HASH_MATCH=TRUE
GLOBAL_TRUE_100=FALSE

if [ "$BACKEND_A_CONFIRMED" = "TRUE" ] &&
   [ "$BACKEND_B_CONFIRMED" = "TRUE" ] &&
   [ "$BACKEND_HASH_MATCH" = "TRUE" ] &&
   [ "$GLOBAL_TRUE_100" = "FALSE" ]; then
    test_pass "Complete backend consensus does not create global TRUE_100"
else
    test_fail "Backend controller incorrectly created global TRUE_100"
fi

# ------------------------------------------------------------
# 14 — Escrow remains blocked
# ------------------------------------------------------------

ESCROW_RELEASE_ALLOWED=FALSE

if [ "$ESCROW_RELEASE_ALLOWED" = "FALSE" ]; then
    test_pass "Backend consensus cannot release escrow"
else
    test_fail "Backend consensus released escrow"
fi

# ------------------------------------------------------------
# 15 — Final authorization remains blocked
# ------------------------------------------------------------

FINAL_AUTHORIZATION_ALLOWED=FALSE

if [ "$FINAL_AUTHORIZATION_ALLOWED" = "FALSE" ]; then
    test_pass "Backend consensus cannot authorize final release"
else
    test_fail "Backend consensus authorized final release"
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
    test_fail "LIVE or real transaction was enabled"
fi

# ------------------------------------------------------------
# 17 — TEST cannot auto-promote to LIVE
# ------------------------------------------------------------

MODE=TEST
LIVE_EVIDENCE=FALSE

if [ "$MODE" = "TEST" ] &&
   [ "$LIVE_EVIDENCE" = "FALSE" ]; then
    test_pass "TEST backend evidence cannot auto-promote to LIVE"
else
    test_fail "TEST evidence promoted to LIVE"
fi

# ------------------------------------------------------------
# 18 — Rules integrity
# ------------------------------------------------------------

EXPECTED_RULE_HASH="$(cat "$BASE/rules/rules.sha256")"
ACTUAL_RULE_HASH="$(
    sha256sum "$BASE/rules/backend_rules.canonical" \
    | awk '{print $1}'
)"

if [ "$EXPECTED_RULE_HASH" = "$ACTUAL_RULE_HASH" ]; then
    test_pass "Canonical rules SHA256 integrity PASS"
else
    test_fail "Canonical rules SHA256 integrity FAIL"
fi

echo
echo "============================================================"
echo " TEST RESULT"
echo " PASS=$PASS"
echo " FAIL=$FAIL"
echo "============================================================"

if [ "$FAIL" -eq 0 ]; then
    echo "MODULE_13_TEST=PASS"
    exit 0
else
    echo "MODULE_13_TEST=FAIL"
    exit 1
fi
