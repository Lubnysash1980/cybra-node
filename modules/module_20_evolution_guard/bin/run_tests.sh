#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
source "$MOD/bin/cybra_evolution.sh"

P=0; F=0
ok()   { echo "[PASS] $1"; P=$((P+1)); }
fail() { echo "[FAIL] $1"; F=$((F+1)); }

echo "============================================================"
echo " CYBRA MODULE 20 — EVOLUTION GUARD"
echo "============================================================"

[ "$TOLERANCE_PERCENT" = "3" ] && ok "Tolerance = 3%" || fail "Tolerance"
if evo_within_tolerance 100 100 3; then ok "Equal values pass"; else fail "Equal"; fi
if evo_within_tolerance 100 110 3; then ok "Improvement pass"; else fail "Improvement"; fi
if evo_within_tolerance 100 97 3; then ok "3% deviation pass"; else fail "3% dev"; fi
if evo_within_tolerance 100 96 3; then fail "4% dev allowed"; else ok "4% dev blocked"; fi
if evo_within_tolerance 100 50 3; then fail "50% dev allowed"; else ok "50% dev blocked"; fi
if evo_within_tolerance 0 0 3; then ok "Zero baseline equal"; else fail "Zero baseline"; fi

[ -f "$OWNER_MARKER" ] && ok "Owner marker exists" || fail "Owner marker"

h="$(evo_hash_tree "$MODULES/module_01_auto_executor")"
[ "${#h}" -eq 64 ] && ok "Hash tree works" || fail "Hash tree (len=${#h})"

tm="module_19_contract_tui_menu"
if [ -d "$MODULES/$tm" ]; then
    evo_approve "$tm" >/dev/null 2>&1
    [ -f "$EVO_DIR/${tm}.approved" ] && ok "Approve works" || fail "Approve"
fi

evo_freeze >/dev/null 2>&1
evo_is_frozen && ok "Freeze activates" || fail "Freeze"

evo_unfreeze >/dev/null 2>&1
! evo_is_frozen && ok "Unfreeze works" || fail "Unfreeze"

evo_snapshot >/dev/null 2>&1
[ -d "$EVO_DIR" ] && ok "Snapshot creates" || fail "Snapshot"

EXPECTED="$(sha256sum "$MOD/rules/evolution_rules.canonical" | awk '{print $1}')"
SAVED="$(cat "$MOD/evidence/rules.sha256" 2>/dev/null)"
[ "$EXPECTED" = "$SAVED" ] && ok "Rules SHA-256 integrity" || fail "Rules hash"

AUTO_HITS=""
while IFS= read -r envf; do
    [ -z "$envf" ] && continue
    case "$envf" in
        *.bak.*|*test_output*|*.log) continue ;;
        */snapshot/*|*/snapshots/*|*/tests/*) continue ;;
    esac
    if grep -qE '^(AUTO_TRANSACTION|AUTO_RELEASE|AUTO_PAYMENT|REAL_TRANSACTION_SENT|GLOBAL_TRUE_100|LIVE_AUTHORIZATION)=TRUE$' "$envf" 2>/dev/null; then
        AUTO_HITS="$AUTO_HITS $envf"
    fi
done < <(find "$MOD" -name '*.env' -type f 2>/dev/null)

[ -z "$AUTO_HITS" ] && ok "No auto transaction" || fail "Auto transaction:$AUTO_HITS"

[ -f "$EVO_LEDGER" ] && ok "Evolution ledger exists" || fail "Ledger"

echo ""
echo "============================================================"
echo " PASS=$P  FAIL=$F"
echo "============================================================"
[ "$F" -eq 0 ] && { echo "MODULE_20_TEST=PASS"; exit 0; } || { echo "MODULE_20_TEST=FAIL"; exit 1; }
