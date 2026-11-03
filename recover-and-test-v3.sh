#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/CYBRA"
ECOSYSTEM="$ROOT/ecosystem.v3.config.js"
MANIFEST="$ROOT/state/manifest.json"
TMP_BASE="${TMPDIR:-$PREFIX/tmp}"

PASS=0
FAIL=0

ok() {
    printf '[PASS] %s\n' "$*"
    PASS=$((PASS + 1))
}

bad() {
    printf '[FAIL] %s\n' "$*"
    FAIL=$((FAIL + 1))
}

pm2_status() {
    pm2 jlist 2>/dev/null |
    node -e '
let data = "";

process.stdin.on("data", chunk => data += chunk);

process.stdin.on("end", () => {
    try {
        const list = JSON.parse(data);
        const name = process.argv[1];
        const processInfo = list.find(item => item.name === name);

        process.stdout.write(
            processInfo?.pm2_env?.status || "missing"
        );
    } catch {
        process.stdout.write("invalid");
    }
});
' "$1"
}

mkdir -p "$TMP_BASE" "$ROOT/state"

echo "========================================"
echo " CYBRA RECOVERY + FUNCTIONAL TEST"
echo "========================================"

echo
echo "=== CORE RECOVERY ==="

CORE_STATUS="$(pm2_status cybra-core)"

if [ "$CORE_STATUS" != "online" ]; then
    echo "[RECOVERY] cybra-core status=$CORE_STATUS"

    if [ -f "$ECOSYSTEM" ]; then
        if pm2 start "$ECOSYSTEM" \
            --only cybra-core \
            --update-env >/dev/null 2>&1; then
            ok "cybra-core started from ecosystem"
        else
            bad "failed to start cybra-core from ecosystem"
        fi
    elif [ -f "$ROOT/core/autonomous-core.js" ]; then
        if pm2 start "$ROOT/core/autonomous-core.js" \
            --name cybra-core \
            --interpreter node \
            --cwd "$ROOT" \
            --time \
            --restart-delay 3000 \
            --max-memory-restart 150M \
            >/dev/null 2>&1; then
            ok "cybra-core started directly"
        else
            bad "failed to start cybra-core directly"
        fi
    else
        bad "autonomous-core.js is missing"
    fi
else
    ok "cybra-core already online"
fi

sleep 5

CORE_STATUS="$(pm2_status cybra-core)"

if [ "$CORE_STATUS" = "online" ]; then
    ok "cybra-core online"
else
    bad "cybra-core status=$CORE_STATUS"
fi

echo
echo "=== MANIFEST LIVE TEST ==="

OLD_TIME="$(stat -c %Y "$MANIFEST" 2>/dev/null || echo 0)"

sleep 17

NEW_TIME="$(stat -c %Y "$MANIFEST" 2>/dev/null || echo 0)"

if [ "$NEW_TIME" -gt "$OLD_TIME" ]; then
    ok "manifest refreshed"
else
    bad "manifest remains stale"
fi

if node -e '
const fs = require("fs");
const manifest = JSON.parse(
    fs.readFileSync(process.argv[1], "utf8")
);

if (
    typeof manifest?.overall?.percent !== "number" ||
    !manifest?.generated_at
) {
    process.exit(1);
}
' "$MANIFEST" 2>/dev/null; then
    ok "manifest structure valid"
else
    bad "manifest structure invalid"
fi

echo
echo "=== CLI ==="

if command -v @cybra >/dev/null 2>&1; then
    ok "@cybra available"
else
    bad "@cybra unavailable"
fi

PCT="$(@cybra -p 2>/dev/null || true)"
COLOR="$(@cybra -c 2>/dev/null || true)"

if printf '%s' "$PCT" |
   grep -Eq '^[0-9]+([.][0-9]+)?$'; then
    ok "health score=$PCT%"
else
    bad "invalid health score=$PCT"
fi

case "$COLOR" in
    green|yellow|red|black)
        ok "health color=$COLOR"
        ;;
    *)
        bad "invalid health color=$COLOR"
        ;;
esac

echo
echo "=== FILESYSTEM TRANSACTION ==="

TEST_FILE="$ROOT/state/.functional-test.$$"

if printf 'CYBRA_TEST_%s\n' "$(date +%s)" > "$TEST_FILE" &&
   grep -q '^CYBRA_TEST_' "$TEST_FILE"; then
    ok "filesystem write/read"
else
    bad "filesystem transaction failed"
fi

rm -f "$TEST_FILE"

echo
echo "=== REDIS TRANSACTION ==="

if command -v redis-cli >/dev/null 2>&1; then
    REDIS_KEY="cybra:test:$$"
    REDIS_VALUE="functional-$(date +%s)"

    if redis-cli PING 2>/dev/null |
       grep -q '^PONG$'; then

        if redis-cli SET \
            "$REDIS_KEY" \
            "$REDIS_VALUE" \
            >/dev/null 2>&1 &&
           [ "$(redis-cli GET "$REDIS_KEY" 2>/dev/null)" = "$REDIS_VALUE" ]; then

            ok "Redis PING + SET/GET"

            redis-cli DEL "$REDIS_KEY" \
                >/dev/null 2>&1 || true
        else
            bad "Redis transaction failed"
        fi
    else
        bad "Redis not responding"
    fi
else
    bad "redis-cli missing"
fi

echo
echo "=== OPENID TRANSACTION ==="

HEALTH_FILE="$TMP_BASE/cybra-health.$$"

if curl -fsS \
    --max-time 5 \
    http://127.0.0.1:8787/health \
    > "$HEALTH_FILE" 2>/dev/null; then

    ok "OpenID health endpoint"

    printf 'Response: '
    cat "$HEALTH_FILE"
    echo
else
    bad "OpenID 127.0.0.1:8787 unavailable"
fi

rm -f "$HEALTH_FILE"

echo
echo "=== CONTROLLED CORE RESTART ==="

if [ "$(pm2_status cybra-core)" = "online" ]; then
    BEFORE_TIME="$(
        stat -c %Y "$MANIFEST" 2>/dev/null || echo 0
    )"

    if pm2 restart cybra-core \
        --update-env >/dev/null 2>&1; then
        ok "restart command accepted"
    else
        bad "restart command failed"
    fi

    sleep 8

    if [ "$(pm2_status cybra-core)" = "online" ]; then
        ok "cybra-core returned online"
    else
        bad "cybra-core failed after restart"
    fi

    sleep 17

    AFTER_TIME="$(
        stat -c %Y "$MANIFEST" 2>/dev/null || echo 0
    )"

    if [ "$AFTER_TIME" -gt "$BEFORE_TIME" ]; then
        ok "manifest resumed after restart"
    else
        bad "manifest did not resume after restart"
    fi
else
    bad "restart test skipped because core is offline"
fi

echo
echo "=== CURRENT COMPONENTS ==="

@cybra components 2>/dev/null || true

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
