#!/data/data/com.termux/files/usr/bin/bash
P=0;F=0
[ -d "$(dirname "$0")/../data" ] && { echo "[PASS] dir";P=$((P+1)); } || { echo "[FAIL] dir";F=$((F+1)); }
echo "  (camera/pdf optional)"
echo "PASS=$P FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_34_TEST=PASS" || echo "MODULE_34_TEST=FAIL"
