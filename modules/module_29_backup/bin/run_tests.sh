#!/data/data/com.termux/files/usr/bin/bash
source "$(dirname "$0")/../bin/backup.sh"
P=0;F=0
command -v tar >/dev/null && { echo "[PASS] tar";P=$((P+1)); } || { echo "[FAIL] tar";F=$((F+1)); }
[ -d "$LOCAL" ] && { echo "[PASS] dir";P=$((P+1)); } || { echo "[FAIL] dir";F=$((F+1)); }
echo "PASS=$P FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_29_TEST=PASS" || echo "MODULE_29_TEST=FAIL"
