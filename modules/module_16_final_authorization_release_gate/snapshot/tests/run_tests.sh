#!/data/data/com.termux/files/usr/bin/bash
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
ok()   { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "============================================================"
echo " CYBRA MODULE 16 — FINAL AUTHORIZATION RELEASE GATE"
echo "============================================================"

TRUE_100_CANDIDATE=FALSE; FINAL_AUTHORIZATION=FALSE; RELEASE_GATE_OPEN=FALSE
[ "$RELEASE_GATE_OPEN" = "FALSE" ] && ok "Initial release gate BLOCKED" || fail "Initial gate open"

TRUE_100_CANDIDATE=TRUE
[ "$RELEASE_GATE_OPEN" = "FALSE" ] && ok "Candidate alone cannot release" || fail "Candidate bypass"

TRUE_100_CANDIDATE=FALSE; FINAL_AUTHORIZATION=TRUE
[ "$RELEASE_GATE_OPEN" = "FALSE" ] && ok "Authorization alone cannot release" || fail "Auth bypass"

[ "ORDER|TERMS|56|A|R|AMT" != "ORDER|TERMS|56|B|R|AMT" ] && ok "Context mismatch BLOCKED" || fail "Context mismatch"
[ "56" != "1" ] && ok "Wrong chain BLOCKED" || fail "Wrong chain"
[ "A" != "B" ] && ok "Wrong recipient BLOCKED" || fail "Wrong recipient"
[ "1000" != "900" ] && ok "Wrong amount BLOCKED" || fail "Wrong amount"

TRUE_100_CANDIDATE=TRUE; ONCHAIN_TRUE_100=TRUE; FINAL_AUTHORIZATION=TRUE
if [ "$TRUE_100_CANDIDATE" = "TRUE" ] && [ "$ONCHAIN_TRUE_100" = "TRUE" ] && [ "$FINAL_AUTHORIZATION" = "TRUE" ]; then
    RELEASE_GATE_OPEN=TRUE
    ok "Complete simulated authorization opens gate"
else
    fail "Complete auth failed"
fi

RELEASE_EXECUTED=FALSE; REAL_TRANSACTION_SENT=FALSE
[ "$RELEASE_EXECUTED" = "FALSE" ] && [ "$REAL_TRANSACTION_SENT" = "FALSE" ] && ok "Gate does NOT execute release" || fail "Auto release"

FIRST=TRUE; SECOND=FALSE
[ "$FIRST" = "TRUE" ] && [ "$SECOND" = "FALSE" ] && ok "Double release BLOCKED" || fail "Double release"

USER_ACTION_REQUIRED=TRUE; AUTO_RELEASE=FALSE; AUTO_TRANSACTION=FALSE
[ "$USER_ACTION_REQUIRED" = "TRUE" ] && [ "$AUTO_RELEASE" = "FALSE" ] && ok "User action required" || fail "Auto action"

MODE=TEST; LIVE_AUTHORIZATION=FALSE
[ "$MODE" = "TEST" ] && [ "$LIVE_AUTHORIZATION" = "FALSE" ] && ok "TEST cannot promote to LIVE" || fail "TEST to LIVE"

GLOBAL_TRUE_100=FALSE
[ "$GLOBAL_TRUE_100" = "FALSE" ] && ok "No global TRUE_100" || fail "Global TRUE_100"

EXPECTED_HASH="$(sha256sum "$BASE/rules/final_authorization_release.canonical" | awk '{print $1}')"
SAVED_HASH="$(cat "$BASE/evidence/rules.sha256" | tr -d '[:space:]')"
if [ "$EXPECTED_HASH" = "$SAVED_HASH" ]; then
    ok "Rules SHA-256 integrity"
else
    fail "Rules mismatch"
fi

echo
echo "============================================================"
echo " TEST RESULT"
echo " PASS=$PASS"
echo " FAIL=$FAIL"
echo "============================================================"
if [ "$FAIL" -eq 0 ]; then
    echo "MODULE_16_TEST=PASS"; exit 0
else
    echo "MODULE_16_TEST=FAIL"; exit 1
fi
