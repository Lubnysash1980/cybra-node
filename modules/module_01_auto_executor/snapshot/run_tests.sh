#!/data/data/com.termux/files/usr/bin/bash
set -u
BASE="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE/state/state.env"
PASS=0; FAIL=0
ok()   { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "============================================================"
echo " CYBRA MODULE 01 — AUTO EXECUTOR"
echo "============================================================"

[ "$MODULE_ID" = "MODULE_01_AUTO_EXECUTOR" ] && ok "MODULE_ID" || fail "MODULE_ID"
[ "$MODE" = "TEST" ] && ok "TEST mode" || fail "TEST mode"
[ "$STATUS" = "PENDING" ] && ok "Initial PENDING" || fail "Initial status"
[ "$TRUE_100" = "FALSE" ] && ok "TRUE_100 false" || fail "TRUE_100"
[ "$RELEASE" = "BLOCKED" ] && ok "Release blocked" || fail "Release"
[ "$AUTO_TRANSACTION" = "FALSE" ] && ok "Auto transaction disabled" || fail "Auto tx"
[ "$AUTO_RELEASE" = "FALSE" ] && ok "Auto release disabled" || fail "Auto release"
[ "$REAL_TRANSACTION_SENT" = "FALSE" ] && ok "No real transaction" || fail "Real tx"
[ "$LIVE_AUTHORIZATION" = "FALSE" ] && ok "LIVE authorization blocked" || fail "LIVE auth"

echo
echo "============================================================"
echo " TEST RESULT"
echo " PASS=$PASS"
echo " FAIL=$FAIL"
echo "============================================================"
if [ "$FAIL" -eq 0 ]; then
    echo "MODULE_01_TEST=PASS"; exit 0
else
    echo "MODULE_01_TEST=FAIL"; exit 1
fi
