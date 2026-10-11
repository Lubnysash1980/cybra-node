#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════
# CYBRA NODE — працює ТІЛЬКИ з @cybra node
# Перевірка → автотест → пуш → безперервно
# ═══════════════════════════════════════════════════════════
set -u
ROOT="$HOME/CYBRA"
NODE="$ROOT/@cybra"
MODULES="$ROOT/modules"
GITMOD="$ROOT/git_module"
REPO="https://github.com/Lubnysash1980/cybra-node.git"
PIDFILE="$ROOT/.cybra_node.pid"
LOG="$ROOT/logs/cybra_node.log"

mkdir -p "$NODE/modules" "$ROOT/logs"

G=$'\033[32m'; Y=$'\033[33m'; R=$'\033[31m'
B=$'\033[1m'; C=$'\033[36m'; Z=$'\033[0m'
ok(){ printf '  %s[✓]%s %s\n' "$G" "$Z" "$*"; }
warn(){ printf '  %s[!]%s %s\n' "$Y" "$Z" "$*"; }
err(){ printf '  %s[✗]%s %s\n' "$R" "$Z" "$*"; }
hdr(){ printf '\n%s═══ %s ═══%s\n' "$B$C" "$*" "$Z"; }
log(){ printf '%s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG"; }

# ─── 1. Перевірка ───
node_check() {
    hdr "NODE CHECK"
    local miss=0 total=0

    # Директорії
    for d in "$NODE" "$NODE/modules" "$GITMOD"; do
        if [ -d "$d" ]; then
            ok "dir: ${d#$ROOT/}"
        else
            mkdir -p "$d"
            warn "created: ${d#$ROOT/}"
            miss=$((miss+1))
        fi
    done

    # Індекс файли
    for f in "$NODE/index.txt" "$NODE/index.json"; do
        if [ -f "$f" ]; then
            ok "file: $(basename "$f")"
        else
            warn "missing: $(basename "$f")"
            miss=$((miss+1))
        fi
    done

    # Модулів
    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        m="$(basename "$d")"
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue;; esac
        total=$((total+1))
    done
    ok "modules: $total"

    # Symlinks
    local linked=$(ls "$NODE/modules" 2>/dev/null | wc -l)
    ok "symlinks: $linked"

    # Git
    if [ -d "$GITMOD/.git" ]; then
        ok "git repo"
        (cd "$GITMOD" && git remote get-url origin >/dev/null 2>&1) && ok "git remote" || warn "no remote"
    else
        err "no git repo"
        miss=$((miss+1))
    fi

    log "CHECK: missing=$miss modules=$total"
    return $miss
}

# ─── 2. Авто-фікс ───
node_fix() {
    hdr "NODE FIX"

    # Re-build index
    printf '# CYBRA NODE\n# %s\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$NODE/index.txt"

    local first=1 count=0
    printf '{\n"updated":"%s",\n"modules":[\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$NODE/index.json"

    for d in "$MODULES"/*/; do
        [ -d "$d" ] || continue
        m="$(basename "$d")"
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue;; esac
        count=$((count+1))

        h="$(cat "$ROOT/baseline/${m}.tree" 2>/dev/null || echo NOHASH)"
        p="$(cat "$ROOT/baseline/${m}.pass" 2>/dev/null || echo 0)"
        f="$(cat "$ROOT/baseline/${m}.fail" 2>/dev/null || echo 0)"

        printf '%s p=%s f=%s %s\n' "$m" "$p" "$f" "${h:0:16}" >> "$NODE/index.txt"

        [ "$first" -eq 0 ] && printf ',\n' >> "$NODE/index.json"
        first=0
        printf '{"name":"%s","pass":%s,"fail":%s,"tree":"%s"}' "$m" "$p" "$f" "$h" >> "$NODE/index.json"

        ln -sfn "$d" "$NODE/modules/$m"
    done

    printf '\n],\n"count":%d\n}\n' "$count" >> "$NODE/index.json"

    ok "index rebuilt: $count modules"
    log "FIX: rebuilt index with $count modules"
}

# ─── 3. Авто-тест ───
node_test() {
    hdr "NODE TEST"
    local pass=0 fail=0

    # 1. Index валідний JSON
    if python3 -c "import json; json.load(open('$NODE/index.json'))" 2>/dev/null; then
        ok "index.json valid"
        pass=$((pass+1))
    else
        err "index.json invalid"
        fail=$((fail+1))
    fi

    # 2. Кожен модуль в index існує
    while IFS= read -r m; do
        [ -z "$m" ] && continue
        if [ -d "$MODULES/$m" ]; then
            pass=$((pass+1))
        else
            err "missing dir: $m"
            fail=$((fail+1))
        fi
    done < <(python3 -c "
import json
for m in json.load(open('$NODE/index.json'))['modules']:
    print(m['name'])
" 2>/dev/null)

    # 3. Symlinks коректні
    for link in "$NODE/modules"/*; do
        [ -L "$link" ] || continue
        if [ ! -e "$link" ]; then
            warn "broken symlink: $(basename "$link")"
            fail=$((fail+1))
        fi
    done

    printf '\n  PASS: %s  FAIL: %s\n' "$pass" "$fail"
    log "TEST: pass=$pass fail=$fail"
    [ "$fail" -eq 0 ] && return 0 || return 1
}

# ─── 4. Sync у git_module ───
node_sync() {
    hdr "NODE SYNC → git_module"

    mkdir -p "$GITMOD/meta" "$GITMOD/modules"

    cp "$NODE/index.json" "$GITMOD/meta/"
    cp "$NODE/index.txt"  "$GITMOD/meta/"

    # Manifest
    cat > "$GITMOD/manifest.txt" <<EOF
CYBRA NODE
UPDATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
MODULES=$(python3 -c "import json; print(json.load(open('$NODE/index.json')).get('count',0))" 2>/dev/null || echo 0)
LICENSE=0x66434c5501242ccC71b5a39C765892921624B66c
POLICY=STRICT_NON_DEGRADATION_3PCT
EOF

    ok "synced"
    log "SYNC: to git_module"
}

# ─── 5. Push ───
node_push() {
    hdr "NODE PUSH"

    cd "$GITMOD" || return 1
    git add -A 2>/dev/null

    if [ -z "$(git status --porcelain 2>/dev/null)" ]; then
        ok "no changes"
        return 0
    fi

    git commit -m "node sync $(date -u +%Y%m%dT%H%M%SZ)" 2>&1 | tail -1

    # Push з перевіркою exit code
    local out
    out="$(git push origin main 2>&1)"
    if printf '%s' "$out" | grep -qE 'main -> main|Everything up-to-date'; then
        ok "PUSHED"
    else
        err "push failed"
        printf '%s\n' "$out" | tail -3 | sed 's/^/    /'
        return 1
    fi

    log "PUSH: ok"
}

# ─── 6. Повний цикл ───
node_cycle() {
    node_check
    node_fix
    node_test || return 1
    node_sync
    node_push || return 1
    return 0
}

# ─── 7. Runtime (безперервно) ───
node_loop() {
    while true; do
        log "LOOP start"
        if node_cycle; then
            log "LOOP ok"
        else
            log "LOOP fail"
        fi
        sleep 300
    done
}

# ─── CLI ───
case "${1:-run}" in
    check|c)   node_check ;;
    fix|f)     node_fix ;;
    test|t)    node_test ;;
    sync|s)    node_sync ;;
    push|p)    node_push ;;
    run|r)     node_cycle ;;
    start)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            warn "already running (PID $(cat "$PIDFILE"))"
            exit 1
        fi
        nohup bash -c "source '$0'; node_loop" >> "$LOG" 2>&1 &
        echo $! > "$PIDFILE"
        ok "node runtime started PID=$(cat "$PIDFILE")"
        ;;
    stop)
        [ ! -f "$PIDFILE" ] && { warn "not running"; exit 1; }
        kill "$(cat "$PIDFILE")" 2>/dev/null
        rm -f "$PIDFILE"
        ok "stopped"
        ;;
    status)
        hdr "NODE STATUS"
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
            ok "runtime RUNNING (PID $(cat "$PIDFILE"))"
        else
            printf '  [·] runtime STOPPED\n'
        fi
        printf '\n  Останні 10 логів:\n'
        tail -10 "$LOG" 2>/dev/null | sed 's/^/    /'
        ;;
    *)
        echo "Usage: cybra_node [check|fix|test|sync|push|run|start|stop|status]"
        ;;
esac
