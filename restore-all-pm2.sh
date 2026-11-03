#!/data/data/com.termux/files/usr/bin/bash

set -u

ROOT="$HOME/CYBRA"
REPORT="$ROOT/recovery/restore-all-pm2.log"

mkdir -p "$ROOT/recovery" "$ROOT/bin"

exec > >(tee -a "$REPORT") 2>&1

echo "========================================"
echo " CYBRA PM2 FULL RESTORE"
echo "========================================"
echo "Started: $(date)"
echo

FOUND=0
STARTED=0
SKIPPED=0
FAILED=0

pm2_has() {
    pm2 jlist 2>/dev/null |
    node -e '
let data = "";

process.stdin.on("data", chunk => data += chunk);

process.stdin.on("end", () => {
    try {
        const list = JSON.parse(data);
        const name = process.argv[1];

        process.exit(
            list.some(item => item.name === name)
                ? 0
                : 1
        );
    } catch {
        process.exit(1);
    }
});
' "$1"
}

pm2_state() {
    pm2 jlist 2>/dev/null |
    node -e '
let data = "";

process.stdin.on("data", chunk => data += chunk);

process.stdin.on("end", () => {
    try {
        const list = JSON.parse(data);
        const name = process.argv[1];
        const item = list.find(process => process.name === name);

        process.stdout.write(
            item?.pm2_env?.status || "missing"
        );
    } catch {
        process.stdout.write("invalid");
    }
});
' "$1"
}

find_entrypoint() {
    local patterns="$1"

    find "$ROOT" -type f 2>/dev/null |
    grep -E '\.(js|py|sh)$' |
    grep -Ei "$patterns" |
    grep -Ev \
'/backups/|/provisioner-|/node_modules/|/downloads/|auto_fix|install|patch|setup|test|backup|bootstrap' |
    head -1
}

start_file() {
    local name="$1"
    local file="$2"

    if [ -z "$file" ] || [ ! -f "$file" ]; then
        echo "[SKIP] $name: entrypoint not found"
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    FOUND=$((FOUND + 1))

    if pm2_has "$name"; then
        echo "[EXISTS] $name: $(pm2_state "$name")"
        return
    fi

    local directory
    local extension
    local interpreter

    directory="$(dirname "$file")"
    extension="${file##*.}"

    case "$extension" in
        js)
            interpreter="node"
            ;;
        py)
            interpreter="python3"
            ;;
        sh)
            interpreter="bash"
            ;;
        *)
            echo "[SKIP] $name: unsupported file $file"
            SKIPPED=$((SKIPPED + 1))
            return
            ;;
    esac

    echo "[START] $name"
    echo "        file=$file"
    echo "        interpreter=$interpreter"
    echo "        cwd=$directory"

    if pm2 start "$file" \
        --name "$name" \
        --interpreter "$interpreter" \
        --cwd "$directory" \
        --time \
        --restart-delay 3000 \
        --max-restarts 10 \
        >/dev/null 2>&1; then

        STARTED=$((STARTED + 1))
        echo "[OK] $name registered"
    else
        FAILED=$((FAILED + 1))
        echo "[FAIL] $name could not start"
    fi
}

echo "=== EXISTING CORE ==="

if pm2_has cybra-core; then
    echo "[OK] cybra-core already registered"
else
    if [ -f "$ROOT/ecosystem.v3.config.js" ]; then
        pm2 start "$ROOT/ecosystem.v3.config.js" \
            --only cybra-core \
            --update-env
    elif [ -f "$ROOT/core/autonomous-core.js" ]; then
        start_file \
            cybra-core \
            "$ROOT/core/autonomous-core.js"
    fi
fi

echo
echo "=== REDIS ==="

if ! command -v redis-server >/dev/null 2>&1; then
    echo "[INSTALL] Redis"
    pkg install redis -y
fi

cat > "$ROOT/bin/redis-pm2.sh" <<'REDIS'
#!/data/data/com.termux/files/usr/bin/bash

mkdir -p "$HOME/CYBRA/state/redis"

exec redis-server \
    --bind 127.0.0.1 \
    --port 6379 \
    --protected-mode yes \
    --daemonize no \
    --appendonly yes \
    --dir "$HOME/CYBRA/state/redis"
REDIS

chmod 755 "$ROOT/bin/redis-pm2.sh"

if pm2_has redis; then
    pm2 restart redis --update-env >/dev/null 2>&1 || true
else
    start_file redis "$ROOT/bin/redis-pm2.sh"
fi

echo
echo "=== OPENID ==="

OPENID_FILE=""

for candidate in \
    "$ROOT/openid/server.js" \
    "$ROOT/openid/index.js" \
    "$ROOT/openid/app.js"
do
    if [ -f "$candidate" ]; then
        OPENID_FILE="$candidate"
        break
    fi
done

if [ -z "$OPENID_FILE" ]; then
    OPENID_FILE="$(
        find_entrypoint \
        'openid.*(server|index|app)|(server|index|app).*openid'
    )"
fi

start_file cybra-openid "$OPENID_FILE"

echo
echo "=== CYBRA COMPONENTS ==="

start_file \
    cybra-api \
    "$(find_entrypoint 'cybra[-_]?api|api[-_]?server')"

start_file \
    cybra-complex \
    "$(find_entrypoint 'cybra[-_]?complex|complex[-_]?(core|worker|server)')"

start_file \
    cybra-evo-ctrl \
    "$(find_entrypoint 'evo[-_]?(ctrl|controller)|evolution[-_]?controller')"

start_file \
    cybra-evolution \
    "$(find_entrypoint 'cybra[-_]?evolution|evolution[-_]?(engine|worker)')"

start_file \
    cybra-git-sync \
    "$(find_entrypoint 'git[-_]?sync')"

start_file \
    cybra-hotreload \
    "$(find_entrypoint 'hot[-_]?reload|hotreload')"

start_file \
    cybra-neuro-core \
    "$(find_entrypoint 'neuro[-_]?(core|controller|engine)')"

start_file \
    cybra-oracle \
    "$(find_entrypoint 'oracle[-_]?(core|worker|engine)|cybra[-_]?oracle')"

start_file \
    cybra-resurrect \
    "$(find_entrypoint 'resurrect|resurrection')"

start_file \
    cybra-stage \
    "$(find_entrypoint 'cybra[-_]?stage|stage[-_]?(worker|controller)')"

start_file \
    cybra-token-guard \
    "$(find_entrypoint 'token[-_]?(guard|gate|guardian)')"

start_file \
    hidl-notifier \
    "$(find_entrypoint 'hidl[-_]?notifier')"

start_file \
    hidl-worker \
    "$(find_entrypoint 'hidl[-_]?worker')"

start_file \
    menu-autorobot \
    "$(find_entrypoint 'menu[-_]?autorobot|autorobot[-_]?menu')"

start_file \
    menu-worker \
    "$(find_entrypoint 'menu[-_]?worker')"

start_file \
    parliament \
    "$(find_entrypoint 'parliament[-_]?(executor|worker|server)|parliament_executor')"

start_file \
    taxi-events \
    "$(find_entrypoint 'taxi[-_]?(events|event|worker)')"

echo
echo "=== SETTLE ==="

sleep 10

echo
echo "=== FUNCTIONAL CHECKS ==="

if redis-cli PING 2>/dev/null |
   grep -q '^PONG$'; then
    echo "[PASS] Redis PONG"
else
    echo "[FAIL] Redis transaction unavailable"
    FAILED=$((FAILED + 1))
fi

if curl -fsS \
    --max-time 5 \
    http://127.0.0.1:8787/health \
    >/dev/null 2>&1; then

    echo "[PASS] OpenID health"
else
    echo "[WARN] OpenID health unavailable"
fi

echo
echo "=== PM2 STATUS ==="

pm2 status

echo
echo "=== NON-ONLINE PROCESSES ==="

pm2 jlist |
node -e '
let data = "";

process.stdin.on("data", chunk => data += chunk);

process.stdin.on("end", () => {
    const list = JSON.parse(data);

    const failed = list.filter(
        item => item.pm2_env?.status !== "online"
    );

    if (!failed.length) {
        console.log("none");
        return;
    }

    for (const item of failed) {
        console.log(
            `${item.name}\t${item.pm2_env?.status}\t` +
            `${item.pm2_env?.pm_exec_path || "unknown"}`
        );
    }
});
'

echo
echo "=== SUMMARY ==="
echo "Found:   $FOUND"
echo "Started: $STARTED"
echo "Skipped: $SKIPPED"
echo "Failed:  $FAILED"

ONLINE_COUNT="$(
    pm2 jlist |
    node -e '
let data = "";

process.stdin.on("data", chunk => data += chunk);

process.stdin.on("end", () => {
    const list = JSON.parse(data);

    process.stdout.write(
        String(
            list.filter(
                item => item.pm2_env?.status === "online"
            ).length
        )
    );
});
'
)"

echo "Online:  $ONLINE_COUNT"

if [ "$ONLINE_COUNT" -ge 3 ]; then
    echo
    echo "[SAVE] Creating complete PM2 dump"

    mkdir -p "$ROOT/recovery"

    if [ -f "$HOME/.pm2/dump.pm2" ]; then
        cp "$HOME/.pm2/dump.pm2" \
           "$ROOT/recovery/dump.before-restore.$(date +%Y%m%d-%H%M%S).pm2"
    fi

    pm2 save

    cp "$HOME/.pm2/dump.pm2" \
       "$ROOT/recovery/dump.functional.$(date +%Y%m%d-%H%M%S).pm2"

    echo "[OK] PM2 registry saved"
else
    echo
    echo "[WARN] Too few online services; PM2 dump not saved"
fi

echo
echo "Report:"
echo "$REPORT"
