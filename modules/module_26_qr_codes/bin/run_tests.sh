#!/data/data/com.termux/files/usr/bin/bash
source "$(dirname "$0")/../bin/qr.sh"
P=0;F=0
command -v qrencode >/dev/null 2>&1 && { echo "[PASS] qrencode";P=$((P+1)); } || { echo "[FAIL] qrencode";F=$((F+1)); }
echo "PASS=$P FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_26_TEST=PASS" || echo "MODULE_26_TEST=FAIL"
