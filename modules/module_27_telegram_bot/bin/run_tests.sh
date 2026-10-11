#!/data/data/com.termux/files/usr/bin/bash
source "$(dirname "$0")/../bin/tg.sh"
P=0;F=0
[ -f "$CONF" ] && { echo "[PASS] config";P=$((P+1)); } || { echo "[FAIL] config";F=$((F+1)); }
command -v curl >/dev/null 2>&1 && { echo "[PASS] curl";P=$((P+1)); } || { echo "[FAIL] curl";F=$((F+1)); }
echo "PASS=$P FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_27_TEST=PASS" || echo "MODULE_27_TEST=FAIL"
