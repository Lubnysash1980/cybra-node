#!/data/data/com.termux/files/usr/bin/bash
source "$(dirname "$0")/../bin/audit.sh"
P=0;F=0
H1="$(au_append "test" "create" "C-1" "{}")"
[ -n "$H1" ] && { echo "[PASS] append";P=$((P+1)); } || { echo "[FAIL] append";F=$((F+1)); }
H2="$(au_append "test" "update" "C-1" "{}")"
au_verify 2>&1 | grep -q "OK" && { echo "[PASS] verify";P=$((P+1)); } || { echo "[FAIL] verify";F=$((F+1)); }
echo "PASS=$P FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_33_TEST=PASS" || echo "MODULE_33_TEST=FAIL"
