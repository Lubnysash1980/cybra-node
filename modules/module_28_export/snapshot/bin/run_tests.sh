#!/data/data/com.termux/files/usr/bin/bash
source "$(dirname "$0")/../bin/export.sh"
P=0;F=0
exp_contracts_csv >/dev/null 2>&1 && { echo "[PASS] csv";P=$((P+1)); } || { echo "[FAIL] csv";F=$((F+1)); }
exp_ledger_csv >/dev/null 2>&1 && { echo "[PASS] ledger";P=$((P+1)); } || { echo "[FAIL] ledger";F=$((F+1)); }
echo "PASS=$P FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_28_TEST=PASS" || echo "MODULE_28_TEST=FAIL"
