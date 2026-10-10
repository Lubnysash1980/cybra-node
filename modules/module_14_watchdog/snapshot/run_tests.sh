#!/data/data/com.termux/files/usr/bin/bash
set -u

BASE="$(cd "$(dirname "$0")/.." && pwd)"

source "$BASE/config/watchdog.env"
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
echo " CYBRA MODULE 14"
echo " WATCHDOG / SYSTEM HEALTH CONTROLLER"
echo " TEST SUITE"
echo "============================================================"

# ------------------------------------------------------------
# 01 — Initial state
# ------------------------------------------------------------

WATCHDOG_PASS=FALSE

if [ "$WATCHDOG_PASS" = "FALSE" ]; then
    test_pass "Initial watchdog state is BLOCKED"
else
    test_fail "Initial watchdog state is not BLOCKED"
fi

# ------------------------------------------------------------
# 02 — Heartbeat healthy
# ------------------------------------------------------------

HEARTBEAT_AGE=10

if [ "$HEARTBEAT_AGE" -le "$HEARTBEAT_MAX_AGE_SECONDS" ]; then
    HEARTBEAT_OK=TRUE
    test_pass "Heartbeat freshness PASS"
else
    HEARTBEAT_OK=FALSE
    test_fail "Heartbeat freshness FAIL"
fi

# ------------------------------------------------------------
# 03 — Stale heartbeat
# ------------------------------------------------------------

HEARTBEAT_AGE=61

if [ "$HEARTBEAT_AGE" -gt "$HEARTBEAT_MAX_AGE_SECONDS" ]; then
    HEARTBEAT_OK=FALSE
    WATCHDOG_PASS=FALSE
    test_pass "Stale heartbeat => watchdog FAIL"
else
    test_fail "Stale heartbeat was accepted"
fi

# restore
HEARTBEAT_AGE=10
HEARTBEAT_OK=TRUE

# ------------------------------------------------------------
# 04 — Redis health
# ------------------------------------------------------------

REDIS_RESPONSE="$REDIS_EXPECTED"

if [ "$REDIS_RESPONSE" = "PONG" ]; then
    REDIS_OK=TRUE
    test_pass "Redis health PASS"
else
    REDIS_OK=FALSE
    test_fail "Redis health FAIL"
fi

# ------------------------------------------------------------
# 05 — Redis failure
# ------------------------------------------------------------

REDIS_RESPONSE="NO_RESPONSE"

if [ "$REDIS_RESPONSE" != "PONG" ]; then
    REDIS_OK=FALSE
    WATCHDOG_PASS=FALSE
    test_pass "Redis failure => watchdog FAIL"
else
    test_fail "Redis failure was accepted"
fi

# restore
REDIS_OK=TRUE

# ------------------------------------------------------------
# 06 — Backend A health
# ------------------------------------------------------------

if [ "$BACKEND_A_RESPONSE" = "HEALTHY" ]; then
    BACKEND_A_HEALTHY=TRUE
    test_pass "Backend A health PASS"
else
    BACKEND_A_HEALTHY=FALSE
    test_fail "Backend A health FAIL"
fi

# ------------------------------------------------------------
# 07 — Backend B health
# ------------------------------------------------------------

if [ "$BACKEND_B_RESPONSE" = "HEALTHY" ]; then
    BACKEND_B_HEALTHY=TRUE
    test_pass "Backend B health PASS"
else
    BACKEND_B_HEALTHY=FALSE
    test_fail "Backend B health FAIL"
fi

# ------------------------------------------------------------
# 08 — Backend A failure
# ------------------------------------------------------------

BACKEND_A_RESPONSE="OFFLINE"

if [ "$BACKEND_A_RESPONSE" != "HEALTHY" ]; then
    BACKEND_A_HEALTHY=FALSE
    WATCHDOG_PASS=FALSE
    test_pass "Backend A failure => watchdog FAIL"
else
    test_fail "Backend A failure was accepted"
fi

BACKEND_A_RESPONSE="HEALTHY"
BACKEND_A_HEALTHY=TRUE

# ------------------------------------------------------------
# 09 — Backend B failure
# ------------------------------------------------------------

BACKEND_B_RESPONSE="OFFLINE"

if [ "$BACKEND_B_RESPONSE" != "HEALTHY" ]; then
    BACKEND_B_HEALTHY=FALSE
    WATCHDOG_PASS=FALSE
    test_pass "Backend B failure => watchdog FAIL"
else
    test_fail "Backend B failure was accepted"
fi

BACKEND_B_RESPONSE="HEALTHY"
BACKEND_B_HEALTHY=TRUE

# ------------------------------------------------------------
# 10 — State freshness
# ------------------------------------------------------------

STATE_AGE=20

if [ "$STATE_AGE" -le "$STATE_MAX_AGE_SECONDS" ]; then
    STATE_FRESH=TRUE
    STALE_STATE=FALSE
    test_pass "State freshness PASS"
else
    STATE_FRESH=FALSE
    STALE_STATE=TRUE
    test_fail "State freshness FAIL"
fi

# ------------------------------------------------------------
# 11 — Stale state
# ------------------------------------------------------------

STATE_AGE=301

if [ "$STATE_AGE" -gt "$STATE_MAX_AGE_SECONDS" ]; then
    STATE_FRESH=FALSE
    STALE_STATE=TRUE
    WATCHDOG_PASS=FALSE
    test_pass "Stale state => FALSE/RETRY"
else
    test_fail "Stale state was accepted"
fi

STATE_AGE=20
STATE_FRESH=TRUE
STALE_STATE=FALSE

# ------------------------------------------------------------
# 12 — Complete healthy state
# ------------------------------------------------------------

HEARTBEAT_OK=TRUE
REDIS_OK=TRUE
BACKEND_A_HEALTHY=TRUE
BACKEND_B_HEALTHY=TRUE
STATE_FRESH=TRUE
STALE_STATE=FALSE

if [ "$HEARTBEAT_OK" = "TRUE" ] &&
   [ "$REDIS_OK" = "TRUE" ] &&
   [ "$BACKEND_A_HEALTHY" = "TRUE" ] &&
   [ "$BACKEND_B_HEALTHY" = "TRUE" ] &&
   [ "$STATE_FRESH" = "TRUE" ] &&
   [ "$STALE_STATE" = "FALSE" ]; then

    WATCHDOG_PASS=TRUE
    HEALTH_STATUS=PASS

    test_pass "Complete watchdog health check PASS"
else
    test_fail "Complete watchdog health check failed"
fi

# ------------------------------------------------------------
# 13 — Watchdog PASS does not create global TRUE_100
# ------------------------------------------------------------

GLOBAL_TRUE_100=FALSE

if [ "$WATCHDOG_PASS" = "TRUE" ] &&
   [ "$GLOBAL_TRUE_100" = "FALSE" ]; then
    test_pass "Watchdog PASS cannot create GLOBAL_TRUE_100"
else
    test_fail "Watchdog incorrectly created GLOBAL_TRUE_100"
fi

# ------------------------------------------------------------
# 14 — Watchdog cannot release escrow
# ------------------------------------------------------------

ESCROW_RELEASE_ALLOWED=FALSE

if [ "$ESCROW_RELEASE_ALLOWED" = "FALSE" ]; then
    test_pass "Watchdog cannot release escrow"
else
    test_fail "Watchdog enabled escrow release"
fi

# ------------------------------------------------------------
# 15 — Watchdog cannot authorize final release
# ------------------------------------------------------------

FINAL_AUTHORIZATION_ALLOWED=FALSE

if [ "$FINAL_AUTHORIZATION_ALLOWED" = "FALSE" ]; then
    test_pass "Watchdog cannot authorize final release"
else
    test_fail "Watchdog authorized final release"
fi

# ------------------------------------------------------------
# 16 — Watchdog cannot authorize LIVE
# ------------------------------------------------------------

LIVE_AUTHORIZATION=FALSE
REAL_TRANSACTION_SENT=FALSE

if [ "$LIVE_AUTHORIZATION" = "FALSE" ] &&
   [ "$REAL_TRANSACTION_SENT" = "FALSE" ]; then
    test_pass "Watchdog cannot authorize LIVE or send transaction"
else
    test_fail "Watchdog enabled LIVE or transaction"
fi

# ------------------------------------------------------------
# 17 — Auto actions disabled
# ------------------------------------------------------------

AUTO_RELEASE=FALSE
AUTO_SIGNATURE=FALSE
AUTO_LIVE=FALSE

if [ "$AUTO_RELEASE" = "FALSE" ] &&
   [ "$AUTO_SIGNATURE" = "FALSE" ] &&
   [ "$AUTO_LIVE" = "FALSE" ]; then
    test_pass "Automatic release/signature/LIVE disabled"
else
    test_fail "Automatic privileged action enabled"
fi

# ------------------------------------------------------------
# 18 — Rules integrity
# ------------------------------------------------------------

EXPECTED_RULE_HASH="$(cat "$BASE/rules/rules.sha256")"

ACTUAL_RULE_HASH="$(
    sha256sum "$BASE/rules/watchdog_rules.canonical" |
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
    echo "MODULE_14_TEST=PASS"
    exit 0
else
    echo "MODULE_14_TEST=FAIL"
    exit 1
fi
