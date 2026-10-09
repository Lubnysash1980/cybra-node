#!/data/data/com.termux/files/usr/bin/bash
source "$(dirname "$0")/../bin/multichain.sh"
P=0;F=0
[ "$(mc_get_id BSC)" = "56" ] && { echo "[PASS] BSC id";P=$((P+1)); } || { echo "[FAIL] BSC id";F=$((F+1)); }
[ "$(mc_get_id ETH)" = "1" ] && { echo "[PASS] ETH id";P=$((P+1)); } || { echo "[FAIL] ETH id";F=$((F+1)); }
[ -n "$(mc_get_rpc POLYGON)" ] && { echo "[PASS] Polygon rpc";P=$((P+1)); } || { echo "[FAIL] Polygon rpc";F=$((F+1)); }
echo "PASS=$P FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_30_TEST=PASS" || echo "MODULE_30_TEST=FAIL"
