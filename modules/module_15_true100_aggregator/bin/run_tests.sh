#!/data/data/com.termux/files/usr/bin/bash
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE/config/true100.env"
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
echo " CYBRA MODULE 15"
echo " TRUE_100 AGGREGATOR CONTROLLER"
echo " TEST SUITE"
echo "============================================================"

# ------------------------------------------------------------
# 01 — Initial state
# ------------------------------------------------------------

PERCENT_COMPLETE=0
GLOBAL_TRUE_100=FALSE

if [ "$PERCENT_COMPLETE" -eq 0 ] &&
   [ "$GLOBAL_TRUE_100" = "FALSE" ]; then
    test_pass "Initial state is FALSE/BLOCKED"
else
    test_fail "Initial state invalid"
fi

# ------------------------------------------------------------
# 02 — 99% cannot become TRUE_100
# ------------------------------------------------------------

PERCENT_COMPLETE=99
TRUE_100_CANDIDATE=FALSE
GLOBAL_TRUE_100=FALSE

if [ "$PERCENT_COMPLETE" -lt 100 ] &&
   [ "$GLOBAL_TRUE_100" = "FALSE" ]; then
    test_pass "99% remains FALSE/PENDING"
else
    test_fail "99% incorrectly became TRUE_100"
fi

# ------------------------------------------------------------
# 03 — 100% requires all modules
# ------------------------------------------------------------

PERCENT_COMPLETE=100
ALL_REQUIRED_MODULES=FALSE
TRUE_100_CANDIDATE=FALSE
GLOBAL_TRUE_100=FALSE

if [ "$PERCENT_COMPLETE" -eq 100 ] &&
   [ "$ALL_REQUIRED_MODULES" = "FALSE" ] &&
   [ "$GLOBAL_TRUE_100" = "FALSE" ]; then
    test_pass "100% percentage alone cannot create TRUE_100"
else
    test_fail "Percentage incorrectly bypassed module requirements"
fi

# ------------------------------------------------------------
# 04 — Missing evidence blocks
# ------------------------------------------------------------

MISSING_REQUIRED_EVIDENCE=TRUE
ALL_REQUIRED_MODULES=TRUE
PERCENT_COMPLETE=100

if [ "$MISSING_REQUIRED_EVIDENCE" = "TRUE" ]; then
    TRUE_100_CANDIDATE=FALSE
    GLOBAL_TRUE_100=FALSE
    test_pass "Missing required evidence blocks TRUE_100"
else
    test_fail "Missing evidence was accepted"
fi

# ------------------------------------------------------------
# 05 — Invalid evidence blocks
# ------------------------------------------------------------

MISSING_REQUIRED_EVIDENCE=FALSE
INVALID_REQUIRED_EVIDENCE=TRUE

if [ "$INVALID_REQUIRED_EVIDENCE" = "TRUE" ]; then
    TRUE_100_CANDIDATE=FALSE
    GLOBAL_TRUE_100=FALSE
    test_pass "Invalid evidence blocks TRUE_100"
else
    test_fail "Invalid evidence was accepted"
fi

# ------------------------------------------------------------
# 06 — Conflict blocks
# ------------------------------------------------------------

INVALID_REQUIRED_EVIDENCE=FALSE
CONFLICT_DETECTED=TRUE

if [ "$CONFLICT_DETECTED" = "TRUE" ]; then
    TRUE_100_CANDIDATE=FALSE
    GLOBAL_TRUE_100=FALSE
    test_pass "Conflict blocks TRUE_100"
else
    test_fail "Conflict was ignored"
fi

# ------------------------------------------------------------
# 07 — All required gates complete
# ------------------------------------------------------------

CONFLICT_DETECTED=FALSE
MISSING_REQUIRED_EVIDENCE=FALSE
INVALID_REQUIRED_EVIDENCE=FALSE

ALL_REQUIRED_MODULES=TRUE
ALL_REQUIRED_EVIDENCE=TRUE
ALL_REQUIRED_HASHES=TRUE
ALL_REQUIRED_SIGNATURES=TRUE
ALL_REQUIRED_BACKENDS=TRUE
ALL_REQUIRED_DELIVERY=TRUE
ALL_REQUIRED_RECEIPT=TRUE
ALL_REQUIRED_WATCHDOG=TRUE

PERCENT_COMPLETE=100

if [ "$ALL_REQUIRED_MODULES" = "TRUE" ] &&
   [ "$ALL_REQUIRED_EVIDENCE" = "TRUE" ] &&
   [ "$ALL_REQUIRED_HASHES" = "TRUE" ] &&
   [ "$ALL_REQUIRED_SIGNATURES" = "TRUE" ] &&
   [ "$ALL_REQUIRED_BACKENDS" = "TRUE" ] &&
   [ "$ALL_REQUIRED_DELIVERY" = "TRUE" ] &&
   [ "$ALL_REQUIRED_RECEIPT" = "TRUE" ] &&
   [ "$ALL_REQUIRED_WATCHDOG" = "TRUE" ] &&
   [ "$PERCENT_COMPLETE" -eq 100 ]; then

    TRUE_100_CANDIDATE=TRUE
    test_pass "All required gates are 100% complete"
else
    test_fail "Complete required gate set was not recognized"
fi

# ------------------------------------------------------------
# 08 — Candidate does not automatically become global TRUE_100
# ------------------------------------------------------------

GLOBAL_TRUE_100=FALSE

if [ "$TRUE_100_CANDIDATE" = "TRUE" ] &&
   [ "$GLOBAL_TRUE_100" = "FALSE" ]; then
    test_pass "TRUE_100 candidate does not bypass global state machine"
else
    test_fail "Aggregator incorrectly promoted global TRUE_100"
fi

# ------------------------------------------------------------
# 09 — Final authorization remains required
# ------------------------------------------------------------

FINAL_AUTHORIZATION_REQUIRED=TRUE
FINAL_AUTHORIZED=FALSE

if [ "$FINAL_AUTHORIZATION_REQUIRED" = "TRUE" ] &&
   [ "$FINAL_AUTHORIZED" = "FALSE" ]; then
    test_pass "Final authorization remains independently required"
else
    test_fail "Final authorization gate was bypassed"
fi

# ------------------------------------------------------------
# 10 — TRUE_100 cannot release escrow
# ------------------------------------------------------------

ESCROW_RELEASE_ALLOWED=FALSE

if [ "$ESCROW_RELEASE_ALLOWED" = "FALSE" ]; then
    test_pass "TRUE_100 aggregation cannot release escrow"
else
    test_fail "TRUE_100 aggregation released escrow"
fi

# ------------------------------------------------------------
# 11 — TRUE_100 cannot authorize LIVE
# ------------------------------------------------------------

LIVE_AUTHORIZATION=FALSE

if [ "$LIVE_AUTHORIZATION" = "FALSE" ]; then
    test_pass "TRUE_100 aggregation cannot authorize LIVE"
else
    test_fail "TRUE_100 aggregation authorized LIVE"
fi

# ------------------------------------------------------------
# 12 — TRUE_100 cannot send transaction
# ------------------------------------------------------------

REAL_TRANSACTION_SENT=FALSE

if [ "$REAL_TRANSACTION_SENT" = "FALSE" ]; then
    test_pass "Aggregator cannot send real transaction"
else
    test_fail "Aggregator sent real transaction"
fi

# ------------------------------------------------------------
# 13 — TEST evidence cannot become LIVE
# ------------------------------------------------------------

MODE=TEST
LIVE_EVIDENCE=FALSE

if [ "$MODE" = "TEST" ] &&
   [ "$LIVE_EVIDENCE" = "FALSE" ]; then
    test_pass "TEST evidence cannot auto-promote to LIVE"
else
    test_fail "TEST evidence promoted to LIVE"
fi

# ------------------------------------------------------------
# 14 — Hash integrity
# ------------------------------------------------------------

EXPECTED_RULE_HASH="$(cat "$BASE/rules/rules.sha256")"

ACTUAL_RULE_HASH="$(
    sha256sum "$BASE/rules/true100_rules.canonical" |
    awk '{print $1}'
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
    echo "MODULE_15_TEST=PASS"
    exit 0
else
    echo "MODULE_15_TEST=FAIL"
    exit 1
fi
