#!/data/data/com.termux/files/usr/bin/bash
source "$(dirname "$0")/../bin/dispute.sh"
P=0;F=0
DID="$(dp_open "C-TEST" "0xAAA" "item not delivered" 2>/dev/null)"
[ -n "$DID" ] && { echo "[PASS] open";P=$((P+1)); } || { echo "[FAIL] open";F=$((F+1)); }
dp_vote "$DID" "BUYER" "REFUND" >/dev/null 2>&1 && { echo "[PASS] vote";P=$((P+1)); } || { echo "[FAIL] vote";F=$((F+1)); }
dp_vote "$DID" "SELLER" "REFUND" 2>&1 | grep -q "RESOLVED" && { echo "[PASS] consensus";P=$((P+1)); } || { echo "[FAIL] consensus";F=$((F+1)); }
echo "PASS=$P FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_31_TEST=PASS" || echo "MODULE_31_TEST=FAIL"
