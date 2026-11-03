#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/CYBRA"
FAIL=0
PASS=0

ok() {
    echo "[PASS] $*"
    PASS=$((PASS + 1))
}

bad() {
    echo "[FAIL] $*"
    FAIL=$((FAIL + 1))
}

echo "========================================"
echo " CYBRA V3 FUNCTIONAL TEST"
echo "========================================"

# 1. PM2
echo
echo "=== PM2 ==="

if pm2 describe cybra-core >/dev/null 2>&1; then
    ok "cybra-core registered"
else
    bad "cybra-core missing"
fi

# 2. CLI
echo
echo "=== CLI ==="

if command -v @cybra >/dev/null 2>&1; then
    ok "@cybra available"
else
    bad "@cybra unavailable"
fi

PCT="$(@cybra -p 2>/dev/null || true)"
COLOR="$(@cybra -c 2>/dev/null || true)"

if printf '%s' "$PCT" | grep -Eq '^[0-9]+([.][0-9]+)?$'; then
    ok "health score valid: $PCT%"
else
    bad "invalid health score: $PCT"
fi

case "$COLOR" in
    green|yellow|red|black)
        ok "health color valid: $COLOR"
        ;;
    *)
        bad "invalid health color: $COLOR"
        ;;
esac

# 3. Manifest
echo
echo "=== MANIFEST ==="

MANIFEST="$ROOT/state/manifest.json"

if node -e '
const fs=require("fs");
const x=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
if (!x.overall) process.exit(1);
' "$MANIFEST" 2>/dev/null; then
    ok "manifest JSON valid"
else
    bad "manifest JSON invalid"
fi

# Test whether generator really updates it
OLD_TIME="$(stat -c %Y "$MANIFEST" 2>/dev/null || echo 0)"

sleep 17

NEW_TIME="$(stat -c %Y "$MANIFEST" 2>/dev/null || echo 0)"

if [ "$NEW_TIME" -gt "$OLD_TIME" ]; then
    ok "manifest generator is active"
else
    bad "manifest was not refreshed"
fi

# 4. Filesystem transaction
echo
echo "=== STORAGE ==="

TESTFILE="$ROOT/state/.cybra-functional-test.$$"

if printf 'CYBRA_TEST_%s\n' "$(date +%s)" > "$TESTFILE" &&
   grep -q 'CYBRA_TEST_' "$TESTFILE"; then
    ok "state filesystem read/write"
else
    bad "state filesystem transaction"
fi

rm -f "$TESTFILE"

# 5. Redis functional transaction
echo
echo "=== REDIS ==="

if command -v redis-cli >/dev/null 2>&1; then

    KEY="cybra:test:$$"
    VALUE="functional-$(date +%s)"

    if redis-cli SET "$KEY" "$VALUE" >/dev/null 2>&1; then

        READ="$(redis-cli GET "$KEY" 2>/dev/null)"

        if [ "$READ" = "$VALUE" ]; then
            ok "Redis SET/GET transaction"
        else
            bad "Redis returned unexpected value"
        fi

        redis-cli DEL "$KEY" >/dev/null 2>&1 || true

    else
        bad "Redis unavailable"
    fi

else
    bad "redis-cli missing"
fi

# 6. OpenID real request
echo
echo "=== OPENID ==="

if curl -fsS --max-time 5 \
    http://127.0.0.1:8787/health \
    >/tmp/cybra-health.$$ 2>/dev/null; then

    ok "OpenID health transaction"

    cat /tmp/cybra-health.$$
    echo

else
    bad "OpenID health endpoint unavailable"
fi

rm -f /tmp/cybra-health.$$

# 7. Controlled core restart
echo
echo "=== RESTART TEST ==="

if pm2 restart cybra-core --update-env >/dev/null 2>&1; then
    ok "cybra-core restart accepted"
else
    bad "cybra-core restart failed"
fi

sleep 8

STATUS="$(
    pm2 jlist 2>/dev/null |
    node -e '
let s="";
process.stdin.on("data",d=>s+=d);
process.stdin.on("end",()=>{
  try {
    const p=JSON.parse(s).find(x=>x.name==="cybra-core");
    process.stdout.write(p?.pm2_env?.status || "missing");
  } catch {
    process.stdout.write("invalid");
  }
});
'
)"

if [ "$STATUS" = "online" ]; then
    ok "cybra-core returned online"
else
    bad "cybra-core status=$STATUS"
fi

# 8. Post-restart manifest
echo
echo "=== POST-RESTART ==="

sleep 17

if @cybra -j >/dev/null 2>&1; then
    ok "@cybra operational after restart"
else
    bad "@cybra failed after restart"
fi

echo
echo "========================================"
echo " RESULT"
echo "========================================"
echo " PASS: $PASS"
echo " FAIL: $FAIL"

if [ "$FAIL" -eq 0 ]; then
    echo " STATUS: FUNCTIONAL"
    exit 0
else
    echo " STATUS: DEGRADED"
    exit 1
fi
