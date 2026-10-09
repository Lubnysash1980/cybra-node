#!/data/data/com.termux/files/usr/bin/bash
set -u
source "$(dirname "$0")/../bin/guardian.sh"

P=0; F=0
ok()   { echo "[PASS] $1"; P=$((P+1)); }
fail() { echo "[FAIL] $1"; F=$((F+1)); }

echo "============================================================"
echo " CYBRA MODULE 35 — GUARDIAN"
echo "============================================================"

# 01 — structure
[ -d "$GUARD_VAULT" ] && ok "vault dir" || fail "vault dir"
[ -d "$GUARD_REC" ] && ok "recovery dir" || fail "recovery dir"

# 02 — hashing
H1="$(gd_hash "test")"
H2="$(gd_hash "test")"
[ "$H1" = "$H2" ] && ok "hash deterministic" || fail "hash deterministic"

H3="$(gd_hash "different")"
[ "$H1" != "$H3" ] && ok "hash unique" || fail "hash unique"

# 03 — device fingerprint
FP="$(gd_device_fingerprint)"
[ -n "$FP" ] && [ "${#FP}" -eq 64 ] && ok "device fp" || fail "device fp"

# 04 — register identity
gd_register "Test User" "1234567890" "0x1111111111111111111111111111111111111111" "bio1" >/dev/null 2>&1 \
    && ok "register" || fail "register"

[ -f "$GUARD_VAULT/identity.env" ] && ok "identity file" || fail "identity file"

# 05 — verify correct
gd_verify "Test User" "1234567890" "0x1111111111111111111111111111111111111111" "bio1" >/dev/null 2>&1 \
    && ok "verify correct" || fail "verify correct"

# 06 — verify wrong
gd_verify "Wrong" "1234567890" "0x1111111111111111111111111111111111111111" >/dev/null 2>&1 \
    && fail "verify wrong accepted" || ok "verify wrong rejected"

# 07 — state check
gd_check_state >/dev/null 2>&1
[ -f "$GUARD_EV/state_pct.txt" ] && ok "state pct file" || fail "state pct"

PCT="$(cat "$GUARD_EV/state_pct.txt" 2>/dev/null || echo 0)"
[ "$PCT" -ge 80 ] && ok "state >= 80% ($PCT%)" || fail "state low: $PCT%"

# 08 — action log
gd_log "test_action" "C-1" "OK"
[ -f "$GUARD_EV/actions.log" ] && ok "action log" || fail "action log"

gd_log_verify 2>&1 | grep -q "^OK:" && ok "log verify" || fail "log verify"

# 09 — rules hash
[ -f "$GUARD_ROOT/state/config.env" ] && ok "config" || fail "config"

# 10 — no auto-money
grep -rq 'AUTO_TRANSACTION=TRUE' "$GUARD_ROOT" 2>/dev/null \
    && fail "auto transaction" || ok "no auto transaction"

echo
echo "============================================================"
echo " PASS=$P  FAIL=$F"
echo "============================================================"

if [ "$F" -eq 0 ]; then
    echo "MODULE_35_TEST=PASS"
    exit 0
else
    echo "MODULE_35_TEST=FAIL"
    exit 1
fi
