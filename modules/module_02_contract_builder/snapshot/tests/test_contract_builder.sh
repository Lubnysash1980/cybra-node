#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

MOD="$(cd "$(dirname "$0")/.." && pwd)"

source "$MOD/state/contract.env"

fail() {
    echo "FALSE: $1"
    exit 1
}

[ "$MODULE_ID" = "MODULE_02_CONTRACT_BUILDER" ] \
    || fail "MODULE_ID"

[ "$MODE" = "TEST" ] \
    || fail "MODE"

[ "$CONTRACT_READY" = "TRUE" ] \
    || fail "CONTRACT_READY"

[ "$TERMS_FROZEN" = "TRUE" ] \
    || fail "TERMS_FROZEN"

[ "$TRUE_100_REQUIRED" = "TRUE" ] \
    || fail "TRUE_100 rule missing"

[ "$FINAL_AUTHORIZATION_REQUIRED" = "TRUE" ] \
    || fail "final authorization rule missing"

[ "$BACKEND_A_REQUIRED" = "TRUE" ] \
    || fail "Backend A rule missing"

[ "$BACKEND_B_REQUIRED" = "TRUE" ] \
    || fail "Backend B rule missing"

[ "$BACKEND_HASH_MATCH_REQUIRED" = "TRUE" ] \
    || fail "Backend hash match rule missing"

[ "$WATCHDOG_REQUIRED" = "TRUE" ] \
    || fail "watchdog rule missing"

[ "$REFUND_RULE_REQUIRED" = "TRUE" ] \
    || fail "refund rule missing"

[ "$DISPUTE_RULE_REQUIRED" = "TRUE" ] \
    || fail "dispute rule missing"

[ -s "$MOD/evidence/terms.canonical" ] \
    || fail "canonical terms missing"

[ -s "$MOD/evidence/terms.sha256" ] \
    || fail "terms hash missing"

HASH="$(sha256sum "$MOD/evidence/terms.canonical" | awk '{print $1}')"
SAVED="$(cat "$MOD/evidence/terms.sha256")"

[ "$HASH" = "$SAVED" ] \
    || fail "TERMS_HASH_MISMATCH"

echo "MODULE_02_TEST=PASS"
echo "CONTRACT_READY=TRUE"
echo "TERMS_FROZEN=TRUE"
echo "TERMS_HASH_MATCH=PASS"
