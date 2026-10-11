#!/data/data/com.termux/files/usr/bin/bash
MOD="$(cd "$(dirname "$0")/.." && pwd)"
P=0; F=0
ok()   { echo "[PASS] $1"; P=$((P+1)); }
fail() { echo "[FAIL] $1"; F=$((F+1)); }

echo "============================================================"
echo " MODULE 02 — CONTRACT BUILDER"
echo "============================================================"

# Структура
[ -d "$MOD" ]           && ok "module dir"      || fail "module dir"
[ -d "$MOD/state" ]     && ok "state dir"       || fail "state dir"
[ -d "$MOD/evidence" ]  && ok "evidence dir"    || fail "evidence dir"
[ -d "$MOD/tests" ]     && ok "tests dir"       || fail "tests dir"

# config.env
CFG="$MOD/state/config.env"
[ -f "$CFG" ] && ok "config.env exists" || fail "config.env missing"

# License recipient — в config.env
if grep -q '0x66434c5501242ccC71b5a39C765892921624B66c' "$CFG" 2>/dev/null; then
    ok "license recipient present"
else
    fail "license recipient missing"
fi

# Security flags FALSE
if grep -qE '^(AUTO_TRANSACTION|REAL_TRANSACTION_SENT|GLOBAL_TRUE_100)=TRUE' "$CFG" 2>/dev/null; then
    fail "auto transaction detected"
else
    ok "no auto transaction"
fi

# Головний скрипт (якщо є в корені)
SCRIPT="$MOD/contract_builder.sh"
if [ -f "$SCRIPT" ]; then
    bash -n "$SCRIPT" 2>/dev/null && ok "script syntax OK" || fail "script syntax"
else
    ok "no script (skip)"
fi

echo ""
echo "PASS=$P  FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_02_TEST=PASS" || echo "MODULE_02_TEST=FAIL"
[ "$F" -eq 0 ] && exit 0 || exit 1
