#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

MOD="$(cd "$(dirname "$0")/.." && pwd)"

source "$MOD/state/escrow.env"

fail() {
    echo "FALSE: $1"
    exit 1
}

[ "$MODULE_ID" = "MODULE_03_ESCROW_CONTROLLER" ] ||
    fail "MODULE_ID"

[ "$MODE" = "TEST" ] ||
    fail "MODE"

[ "$ESCROW_CREATED" = "TRUE" ] ||
    fail "ESCROW_CREATED"

[ "$RELEASE" = "BLOCKED" ] ||
    fail "INITIAL_RELEASE"

[ "$REFUND" = "BLOCKED" ] ||
    fail "INITIAL_REFUND"

[ "$DISPUTE" = "BLOCKED" ] ||
    fail "INITIAL_DISPUTE"

[ "$SECOND_RELEASE" = "BLOCKED" ] ||
    fail "SECOND_RELEASE"

HASH="$(sha256sum "$MOD/evidence/escrow_rules.canonical" |
    awk '{print $1}')"

SAVED="$(cat "$MOD/evidence/rules.sha256")"

[ "$HASH" = "$SAVED" ] ||
    fail "RULES_HASH_MISMATCH"

echo "MODULE_03_TEST=PASS"
echo "ESCROW_CREATED=TRUE"
echo "EARLY_RELEASE=BLOCKED"
echo "RULES_HASH_MATCH=PASS"
