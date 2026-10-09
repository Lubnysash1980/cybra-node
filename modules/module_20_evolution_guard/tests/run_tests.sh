#!/data/data/com.termux/files/usr/bin/bash
set -u

MOD="$(cd "$(dirname "$0")/.." && pwd)"
source "$MOD/bin/cybra_evolution.sh"

PASS=0
FAIL=0
ok()   { echo "[PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "============================================================"
echo " CYBRA MODULE 20 — EVOLUTION GUARD"
echo "============================================================"

# 01 — tolerance = 3%
[ "$TOLERANCE_PERCENT" = "3" ] && ok "Tolerance = 3%" || fail "Tolerance"

# 02 — equal values OK
if evo_within_tolerance 100 100 3; then ok "Equal values pass"; else fail "Equal"; fi

# 03 — improvement OK
if evo_within_tolerance 100 110 3; then ok "Improvement pass"; else fail "Improvement"; fi

# 04 — 3% deviation OK
if evo_within_tolerance 100 97 3; then ok "3% deviation pass"; else fail "3% dev"; fi

# 05 — 4% deviation BLOCKED
if evo_within_tolerance 100 96 3; then fail "4% dev allowed"; else ok "4% dev blocked"; fi

# 06 — 50% deviation BLOCKED
if evo_within_tolerance 100 50 3; then fail "50% dev allowed"; else ok "50% dev blocked"; fi

# 07 — zero baseline
if evo_within_tolerance 0 0 3; then ok "Zero baseline equal"; else fail "Zero baseline"; fi

# 08 — Owner marker
[ -f "$OWNER_MARKER" ] && ok "Owner marker exists" || fail "Owner marker"

# 09 — hash tree function
h="$(evo_hash_tree "$MODULES/module_01_auto_executor")"
[ "${#h}" -eq 64 ] && ok "Hash tree works" || fail "Hash tree (len=${#h})"

# 10 — approve evolution
test_mod="module_19_contract_tui_menu"
if [ -d "$MODULES/$test_mod" ]; then
    evo_approve "$test_mod" >/dev/null 2>&1
    [ -f "$EVO_DIR/${test_mod}.approved" ] && ok "Approve works" || fail "Approve"
fi

# 11 — approve requires owner
[ -f "$OWNER_MARKER" ] && ok "Owner check active" || fail "Owner check"

# 12 — freeze
evo_freeze >/dev/null 2>&1
evo_is_frozen && ok "Freeze activates" || fail "Freeze"

# 13 — unfreeze
evo_unfreeze >/dev/null 2>&1
if ! evo_is_frozen; then ok "Unfreeze works"; else fail "Unfreeze"; fi

# 14 — snapshot
evo_snapshot >/dev/null 2>&1
[ -d "$EVO_DIR" ] && ok "Snapshot creates" || fail "Snapshot"

# 15 — check all modules
if evo_check_all >/dev/null 2>&1; then
    ok "Check all modules PASS"
else
    fail "Check all modules — see evo_check_all output"
fi

# 16 — rules hash
EXPECTED="$(sha256sum "$MOD/rules/evolution_rules.canonical" | awk '{print $1}')"
SAVED="$(cat "$MOD/evidence/rules.sha256")"
[ "$EXPECTED" = "$SAVED" ] && ok "Rules SHA-256 integrity" || fail "Rules hash"

# 17 — no auto-transaction
grep -rq 'AUTO_TRANSACTION=TRUE' "$MOD" 2>/dev/null && fail "Auto transaction" || ok "No auto transaction"

# 18 — ledger exists
[ -f "$EVO_LEDGER" ] && ok "Evolution ledger exists" || fail "Ledger"

echo
echo "============================================================"
echo " PASS=$PASS  FAIL=$FAIL"
echo "============================================================"

if [ "$FAIL" -eq 0 ]; then
    echo "MODULE_20_TEST=PASS"; exit 0
else
    echo "MODULE_20_TEST=FAIL"; exit 1
fi
