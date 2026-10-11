#!/data/data/com.termux/files/usr/bin/bash
source "$(dirname "$0")/../bin/address_book.sh"
P=0;F=0
ok(){ echo "[PASS] $1";P=$((P+1)); }
no(){ echo "[FAIL] $1";F=$((F+1)); }
[ -f "$DB" ] && ok "db exists" || no "db"
ab_add "test1" "0x1111111111111111111111111111111111111111" "buyer" >/dev/null && ok "add" || no "add"
[ "$(ab_get test1)" = "0x1111111111111111111111111111111111111111" ] && ok "get" || no "get"
ab_remove test1 >/dev/null && ok "remove" || no "remove"
echo "PASS=$P FAIL=$F"
[ "$F" -eq 0 ] && echo "MODULE_25_TEST=PASS" || echo "MODULE_25_TEST=FAIL"
