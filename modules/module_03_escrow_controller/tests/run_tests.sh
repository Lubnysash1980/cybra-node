#!/data/data/com.termux/files/usr/bin/bash
MOD="$(cd "$(dirname "$0")/.." && pwd)"
P=0; F=0
ok()   { echo "[PASS] $1"; P=$((P+1)); }
fail() { echo "[FAIL] $1"; F=$((F+1)); }

echo "============================================================"
echo " MODULE 03 — ESCROW CONTROLLER"
echo "============================================================"

# Структура
[ -d "$MOD" ]           && ok "module dir"      || fail "module dir"
[ -d "$MOD/state" ]     && ok "state dir"       || fail "state dir"
[ -d "$MOD/evidence" ]  && ok "evidence dir"    || fail "evidence dir"
[ -d "$MOD/tests" ]     && ok "tests dir"       || fail "tests dir"

# Головний скрипт
SCRIPT="$MOD/escrow_controller.sh"
[ -f "$SCRIPT" ]        && ok "script exists"   || fail "script missing"
[ -x "$SCRIPT" ]        && ok "script exec"     || fail "script not exec"

# Синтаксис
if [ -f "$SCRIPT" ]; then
    bash -n "$SCRIPT" 2>/dev/null && ok "syntax OK" || fail "syntax error"
fi

# Escrow має містити ключові слова
if grep -qE 'escrow|ESCROW|release|refund' "$SCRIPT" 2>/dev/null; then
    ok "escrow logic present"
else
    fail "escrow logic missing"
fi

# Жодних auto-money
if grep -qE '^AUTO_TRANSACTION=TRUE|REAL_TRANSACTION_SENT=TRUE' "$SCRIPT" 2>/dev/null; then
    fail "auto transaction detected"
else
    ok "no auto transaction"
fi

echo ""
echo "PASS=$P  FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_03_TEST=PASS" || echo "MODULE_03_TEST=FAIL"
[ "$F" -eq 0 ] && exit 0 || exit 1
