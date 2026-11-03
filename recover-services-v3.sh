#!/data/data/com.termux/files/usr/bin/bash

set -Eeuo pipefail

ROOT="$HOME/CYBRA"
OPENID="$ROOT/openid"
BIN="$ROOT/bin"
STATE="$ROOT/state"

mkdir -p "$BIN" "$STATE"

ok() {
    printf '[PASS] %s\n' "$*"
}

bad() {
    printf '[FAIL] %s\n' "$*" >&2
}

pm2_has() {
    pm2 jlist 2>/dev/null |
    node -e '
let data = "";

process.stdin.on("data", chunk => data += chunk);

process.stdin.on("end", () => {
    try {
        const list = JSON.parse(data);
        const processName = process.argv[1];

        process.exit(
            list.some(item => item.name === processName)
                ? 0
                : 1
        );
    } catch {
        process.exit(1);
    }
});
' "$1"
}

echo "========================================"
echo " CYBRA SERVICE RECOVERY"
echo "========================================"

# --------------------------------------------------
# Redis
# --------------------------------------------------

echo
echo "=== REDIS ==="

if ! command -v redis-server >/dev/null 2>&1; then
    echo "[INSTALL] redis"
    pkg install redis -y
fi

cat > "$BIN/redis-pm2.sh" <<'REDIS'
#!/data/data/com.termux/files/usr/bin/bash

exec redis-server \
    --port 6379 \
    --bind 127.0.0.1 \
    --protected-mode yes \
    --daemonize no \
    --appendonly yes \
    --dir "$HOME/CYBRA/state"
REDIS

chmod 755 "$BIN/redis-pm2.sh"

if pm2_has redis; then
    pm2 restart redis --update-env
else
    pm2 start "$BIN/redis-pm2.sh" \
        --name redis \
        --interpreter bash \
        --cwd "$ROOT" \
        --time \
        --restart-delay 3000
fi

sleep 3

if redis-cli PING 2>/dev/null |
   grep -q '^PONG$'; then
    ok "Redis PING"
else
    bad "Redis failed to start"
    pm2 logs redis --lines 30 --nostream || true
    exit 1
fi

KEY="cybra:recovery:test:$$"
VALUE="redis-$(date +%s)"

redis-cli SET "$KEY" "$VALUE" >/dev/null

if [ "$(redis-cli GET "$KEY")" = "$VALUE" ]; then
    ok "Redis SET/GET"
else
    bad "Redis transaction failed"
    exit 1
fi

redis-cli DEL "$KEY" >/dev/null

# --------------------------------------------------
# OpenID
# --------------------------------------------------

echo
echo "=== OPENID ==="

SERVER=""

for candidate in \
    "$OPENID/server.js" \
    "$ROOT/server.js" \
    "$ROOT/openid.js"
do
    if [ -f "$candidate" ]; then
        SERVER="$candidate"
        break
    fi
done

if [ -z "$SERVER" ]; then
    SERVER="$(
        find "$ROOT" \
            -type f \
            -name 'server.js' \
            ! -path '*/node_modules/*' \
            ! -path '*/backups/*' \
            -print 2>/dev/null |
        head -1
    )"
fi

if [ -z "$SERVER" ] || [ ! -f "$SERVER" ]; then
    bad "OpenID server.js not found"
    exit 1
fi

SERVER_DIR="$(dirname "$SERVER")"

echo "OpenID entrypoint: $SERVER"

if [ -f "$SERVER_DIR/package.json" ]; then
    (
        cd "$SERVER_DIR"
        npm install
    )
fi

if [ -f "$SERVER_DIR/.env" ]; then
    chmod 600 "$SERVER_DIR/.env"
fi

if pm2_has cybra-openid; then
    pm2 restart cybra-openid --update-env
else
    pm2 start "$SERVER" \
        --name cybra-openid \
        --interpreter node \
        --cwd "$SERVER_DIR" \
        --time \
        --restart-delay 3000 \
        --max-memory-restart 150M
fi

sleep 5

if curl -fsS \
    --max-time 5 \
    http://127.0.0.1:8787/health; then

    echo
    ok "OpenID health endpoint"

else
    bad "OpenID endpoint unavailable"

    pm2 describe cybra-openid || true
    pm2 logs cybra-openid \
        --lines 50 \
        --nostream || true

    exit 1
fi

# --------------------------------------------------
# Core refresh
# --------------------------------------------------

echo
echo "=== CORE REFRESH ==="

pm2 restart cybra-core --update-env

sleep 20

echo
echo "=== FUNCTIONAL STATUS ==="

pm2 status

echo
echo "Redis:"
redis-cli PING

echo
echo "OpenID:"
curl -fsS \
    --max-time 5 \
    http://127.0.0.1:8787/health
echo

echo
echo "CYBRA:"
@cybra
@cybra -r || true

echo
echo "[SUCCESS] Redis and OpenID recovered"
echo
echo "Review the status above."
echo "Only then run: pm2 save"
