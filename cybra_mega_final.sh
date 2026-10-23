#!/data/data/com.termux/files/usr/bin/bash
set -u

ROOT="$HOME/CYBRA"; CONTROL="$ROOT/control"; LOGS="$ROOT/logs"
SNAP_DIR="$HOME/.cybra_snapshots"
ENVF="$HOME/.cybra_remote.env"
PREFIX_BIN="$PREFIX/bin"
BOOT="$HOME/.termux/boot/cybra_boot.sh"

ok(){ printf '\033[32m  OK  %s\033[0m\n' "$*"; }
er(){ printf '\033[31m FAIL %s\033[0m\n' "$*"; }
stp(){ printf '\n\033[36m== %s ==\033[0m\n' "$*"; }

mkdir -p "$CONTROL" "$LOGS" "$SNAP_DIR" "$HOME/.termux/boot"

# ============================================================
# 1. PATH
# ============================================================
stp "1. PATH"
if grep -q '^export PATH=\$HOME/bin:\$PATH' "$HOME/.bashrc" 2>/dev/null; then
    sed -i 's|^export PATH=\$HOME/bin:\$PATH|export PATH=$PREFIX/bin:$HOME/bin:$PATH|' "$HOME/.bashrc"
    ok "fixed"
else
    grep -q 'export PATH=\$PREFIX/bin' "$HOME/.bashrc" || \
        echo 'export PATH=$PREFIX/bin:$HOME/bin:$PATH' >> "$HOME/.bashrc"
    ok "ok"
fi
export PATH="$PREFIX/bin:$HOME/bin:$PATH"
hash -r 2>/dev/null || true

# ============================================================
# 2. Clean broken env
# ============================================================
stp "2. Clean git env"
if [ -f "$ENVF" ] && grep -qE 'YOUR_USER|<url>|Ввести|gitcybra' "$ENVF"; then
    rm -f "$ENVF"
    ok "removed broken"
else
    ok "clean already"
fi

# ============================================================
# 3. cybra_backup_push.sh (bulletproof rotation + git)
# ============================================================
stp "3. Backup script"
cat > "$ROOT/cybra_backup_push.sh" <<'BKP'
#!/data/data/com.termux/files/usr/bin/bash
set -u
ROOT="$HOME/CYBRA"; SNAP_DIR="$HOME/.cybra_snapshots"
STAMP=$(date +%Y%m%d_%H%M%S)
SNAP="$SNAP_DIR/cybra_$STAMP.tar.gz"
LATEST="$SNAP_DIR/latest.tar.gz"
LOG="$ROOT/logs/cybra_backup.log"
mkdir -p "$SNAP_DIR" "$ROOT/logs"
log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }
log "backup start"

tar czf "$SNAP" -C "$HOME" \
    --exclude='CYBRA/logs/*' \
    --exclude='CYBRA/evidence/selftest/*' \
    --exclude='CYBRA/*.bak*' \
    --exclude='CYBRA/control/*.pid' \
    --exclude='CYBRA/.git' \
    CYBRA .cybra_bootstrap.sh .cybra_remote.env 2>/dev/null || true

[ -f "$SNAP" ] || { log "tar failed"; exit 1; }
ln -sf "$SNAP" "$LATEST"
log "size=$(wc -c < "$SNAP")"

# SD mirror
if [ -d "$HOME/storage/shared" ]; then
    SD="$HOME/storage/shared/CYBRA-backup"; mkdir -p "$SD"
    cp -f "$SNAP" "$SD/latest.tar.gz" 2>/dev/null && log "mirror → SD" || true
fi

# Git push (only if real URL)
if [ -f "$HOME/.cybra_remote.env" ]; then
    . "$HOME/.cybra_remote.env"
    if [ -n "${CYBRA_GIT_REMOTE:-}" ] && \
       printf '%s' "$CYBRA_GIT_REMOTE" | grep -qE '^(https?|git)://|^git@'; then
        if command -v git >/dev/null 2>&1; then
            V="$HOME/.cybra_vault"; mkdir -p "$V"
            if [ ! -d "$V/.git" ]; then
                git -C "$V" init -q 2>/dev/null
                git -C "$V" remote add origin "$CYBRA_GIT_REMOTE" 2>/dev/null || \
                    git -C "$V" remote set-url origin "$CYBRA_GIT_REMOTE"
            else
                git -C "$V" remote set-url origin "$CYBRA_GIT_REMOTE" 2>/dev/null || true
            fi
            cp -f "$SNAP" "$V/snapshot.tar.gz"
            cp -f "$HOME/.cybra_bootstrap.sh" "$V/" 2>/dev/null || true
            git -C "$V" add -A >/dev/null 2>&1
            git -C "$V" commit -m "snapshot $STAMP" >/dev/null 2>&1 || true
            if git -C "$V" push -u origin HEAD --force >/dev/null 2>&1; then
                log "git push OK"
            else
                log "git push FAILED"
            fi
        else
            log "git not installed"
        fi
    else
        log "git remote not configured"
    fi
fi

# Bulletproof rotation
KEEP="$(basename "$SNAP")"
find "$SNAP_DIR" -maxdepth 1 -type f -name 'cybra_*.tar.gz' \
    ! -name "$KEEP" -delete 2>/dev/null || true
log "rotated (keeping $KEEP)"
log "backup done"
BKP
chmod +x "$ROOT/cybra_backup_push.sh"
bash -n "$ROOT/cybra_backup_push.sh" && ok "backup" || er "backup syntax"

# ============================================================
# 4. cybra_heal.sh — REPAIR (self-heal + restore if broken)
# ============================================================
stp "4. Heal / Repair"
cat > "$ROOT/cybra_heal.sh" <<'HEAL'
#!/data/data/com.termux/files/usr/bin/bash
set -u
ROOT="$HOME/CYBRA"; CONTROL="$ROOT/control"
SNAP_DIR="$HOME/.cybra_snapshots"
LOG="$ROOT/logs/cybra_heal.log"
mkdir -p "$ROOT/logs" "$CONTROL"
log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG"; }

log "=== HEAL / REPAIR ==="

# 1. Check core files
CORE_OK=true
for f in cybra_master_start.sh cybra_backup_push.sh cybra_autobackup.sh cybra_heal.sh; do
    [ -f "$ROOT/$f" ] || { log "MISSING: $f"; CORE_OK=false; }
done

# 2. Restore from snapshot if broken
if [ "$CORE_OK" = false ] && [ -f "$SNAP_DIR/latest.tar.gz" ]; then
    log "restoring from snapshot..."
    tar xzf "$SNAP_DIR/latest.tar.gz" -C "$HOME" 2>>"$LOG" || true
    chmod +x "$ROOT"/*.sh 2>/dev/null || true
    log "restored"
fi

# 3. Auto-heal
[ -x "$ROOT/04_cybra_auto_heal.sh" ] && "$ROOT/04_cybra_auto_heal.sh" >>"$LOG" 2>&1 || true

# 4. Restart master if dead
P=$(cat "$CONTROL/cybra_master.pid" 2>/dev/null || true)
if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then
    log "master alive pid=$P"; exit 0
fi
log "master down → restart"
nohup "$ROOT/cybra_master_start.sh" >> "$ROOT/logs/cybra_master.log" 2>&1 &
sleep 3
P=$(cat "$CONTROL/cybra_master.pid" 2>/dev/null || true)
[ -n "$P" ] && kill -0 "$P" 2>/dev/null && { log "restarted pid=$P"; exit 0; }
log "heal FAILED"; exit 1
HEAL
chmod +x "$ROOT/cybra_heal.sh"
bash -n "$ROOT/cybra_heal.sh" && ok "heal" || er "heal syntax"

# ============================================================
# 5. cybra_autobackup.sh (auto git push every 30m)
# ============================================================
stp "5. Autobackup"
cat > "$ROOT/cybra_autobackup.sh" <<'AB'
#!/data/data/com.termux/files/usr/bin/bash
set -u
ROOT="$HOME/CYBRA"
PIDFILE="$ROOT/control/cybra_autobackup.pid"
LOG="$ROOT/logs/cybra_autobackup.log"
INTERVAL="${CYBRA_AUTOBACKUP_INTERVAL:-1800}"
mkdir -p "$ROOT/control" "$ROOT/logs"
log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }

if [ -f "$PIDFILE" ]; then
    OLD=$(cat "$PIDFILE" 2>/dev/null || true)
    [ -n "$OLD" ] && [ "$OLD" != "$$" ] && kill -0 "$OLD" 2>/dev/null && exit 0
fi
echo "$$" > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT
log "autobackup started pid=$$ interval=${INTERVAL}s"
while true; do
    sleep "$INTERVAL"
    [ -x "$ROOT/cybra_backup_push.sh" ] && \
        { "$ROOT/cybra_backup_push.sh" >> "$LOG" 2>&1 && log "auto OK" || log "auto FAIL"; }
done
AB
chmod +x "$ROOT/cybra_autobackup.sh"
bash -n "$ROOT/cybra_autobackup.sh" && ok "autobackup" || er "autobackup syntax"

# ============================================================
# 6. cybra_master_start.sh (WATCHDOG: master + wd + autobackup + heal)
# ============================================================
stp "6. Master (watchdog loop)"
cat > "$ROOT/cybra_master_start.sh" <<'MS'
#!/data/data/com.termux/files/usr/bin/bash
set -u
ROOT="$HOME/CYBRA"; CONTROL="$ROOT/control"
LOG="$ROOT/logs/cybra_master.log"
PIDFILE="$CONTROL/cybra_master.pid"
STATE="$CONTROL/cybra_master.state"
INTERVAL=20
mkdir -p "$CONTROL" "$ROOT/logs"
log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock >/dev/null 2>&1 || true

if [ -f "$PIDFILE" ]; then
    OLD=$(cat "$PIDFILE" 2>/dev/null || true)
    if [ -n "$OLD" ] && [ "$OLD" != "$$" ] && kill -0 "$OLD" 2>/dev/null; then
        echo "master already pid=$OLD"; exit 0
    fi
    rm -f "$PIDFILE"
fi
echo "$$" > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT INT TERM
log "master started pid=$$"

spawn_if_dead(){
    local SCRIPT="$1" PIDF="$2" NAME="$3"
    [ -x "$SCRIPT" ] || return 0
    if [ -f "$PIDF" ]; then
        local P=$(cat "$PIDF" 2>/dev/null || true)
        if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then return 0; fi
    fi
    log "$NAME down → restart"
    nohup "$SCRIPT" >> "$LOG" 2>&1 &
    sleep 1
    return 1
}

while true; do
    # network watchdog
    spawn_if_dead "$ROOT/11_cybra_network_master_watchdog.sh" \
                  "$CONTROL/network_master_watchdog.pid" "network-wd" && WD=true || WD=false

    # autobackup
    spawn_if_dead "$ROOT/cybra_autobackup.sh" \
                  "$CONTROL/cybra_autobackup.pid" "autobackup" && AB=true || AB=false

    # node watchdog
    spawn_if_dead "$ROOT/03_cybra_node_watchdog.sh" \
                  "$CONTROL/cybra_node_watchdog.pid" "node-wd" && NWD=true || NWD=false

    NODE=false
    [ -f "$ROOT/node_cybra/bin/cybra_node_start.sh" ] && NODE=true

    cat > "$STATE" <<STATE
MASTER=ONLINE
AUTO_START=true
AUTO_HEAL=true
WAKE_LOCK=true
NODE=$NODE
NETWORK_WATCHDOG=$WD
AUTOBACKUP=$AB
NODE_WATCHDOG=$NWD
TRUE_100=false
LIVE=false
PHYSICAL_EXECUTION=false
LAST_CHECK=$(date +%s)
STATE_REASON=CYBRA_MASTER
STATE

    sleep "$INTERVAL"
done
MS
chmod +x "$ROOT/cybra_master_start.sh"
bash -n "$ROOT/cybra_master_start.sh" && ok "master" || er "master syntax"

# ============================================================
# 7. cybra CLI — extended (git-status, git-pull, repair, watch)
# ============================================================
stp "7. cybra CLI (extended)"
cat > "$PREFIX_BIN/cybra" <<'CLI'
#!/data/data/com.termux/files/usr/bin/bash
set -u
ROOT="$HOME/CYBRA"; CONTROL="$ROOT/control"
cmd="${1:-start}"; shift 2>/dev/null || true

start_all(){
    command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock >/dev/null 2>&1 || true
    if [ ! -x "$ROOT/cybra_master_start.sh" ]; then
        echo "core missing → bootstrap"
        [ -x "$HOME/.cybra_bootstrap.sh" ] && exec "$HOME/.cybra_bootstrap.sh" --force
        echo "bootstrap missing"; exit 1
    fi
    P="$CONTROL/cybra_master.pid"
    if [ -f "$P" ]; then
        X=$(cat "$P" 2>/dev/null || true)
        if [ -n "$X" ] && kill -0 "$X" 2>/dev/null; then
            echo "already running pid=$X"; exit 0
        fi
        rm -f "$P"
    fi
    nohup "$ROOT/cybra_master_start.sh" >> "$ROOT/logs/cybra_master.log" 2>&1 &
    sleep 3
    X=$(cat "$P" 2>/dev/null || true)
    if [ -n "$X" ] && kill -0 "$X" 2>/dev/null; then echo "STARTED pid=$X"
    else echo "START FAILED"; tail -20 "$ROOT/logs/cybra_master.log" 2>/dev/null; exit 1; fi
}
stop_all(){
    k=0
    for f in "$CONTROL"/*.pid; do
        [ -f "$f" ] || continue
        X=$(cat "$f" 2>/dev/null || true)
        [ -n "$X" ] && kill -0 "$X" 2>/dev/null && { kill "$X" 2>/dev/null && k=$((k+1)); }
        rm -f "$f"
    done
    for p in $(ps -A -o pid=,args= 2>/dev/null | awk '/cybra_master_start|network_master_watchdog|cybra_node_watchdog|backup_worker_wifi|cybra_autobackup|ledger_auto_connect/ {print $1}'); do
        kill "$p" 2>/dev/null && k=$((k+1))
    done
    echo "stopped $k"
}
status_show(){
    echo "============================================================"
    echo "CYBRA STATUS  $(date '+%F %T')"
    echo "============================================================"
    echo
    echo "--- MASTER ---"
    cat "$CONTROL/cybra_master.state" 2>/dev/null || echo "(no state)"
    echo
    echo "--- PID FILES ---"
    for f in "$CONTROL"/*.pid; do
        [ -f "$f" ] || continue
        X=$(cat "$f" 2>/dev/null || true)
        printf '  %-38s pid=%-8s ' "$(basename "$f")" "$X"
        if [ -n "$X" ] && kill -0 "$X" 2>/dev/null; then echo ALIVE; else echo DEAD; fi
    done
    echo
    echo "--- WATCHDOG ---"
    cat "$CONTROL/network_master_watchdog.state" 2>/dev/null || echo "(none)"
    echo
    echo "--- SNAPSHOTS ---"
    ls -la "$HOME/.cybra_snapshots/" 2>/dev/null | tail -n +2
    echo
    echo "--- SAFETY ---"
    grep -rhE '^(CYBRA_)?(TRUE_100|LIVE|PHYSICAL_EXECUTION)=' \
        "$CONTROL"/*.env "$CONTROL"/*.state 2>/dev/null | sort -u || true
}
setup_remote(){
    echo "CYBRA GIT REMOTE SETUP"
    echo "  Приклад: https://USER:TOKEN@github.com/USER/cybra-vault.git"
    echo "  Enter = скасувати"
    printf 'URL: '
    IFS= read -r URL
    URL=$(printf '%s' "$URL" | tr -d '\r\n')
    [ -z "$URL" ] && { echo "cancelled"; exit 0; }
    case "$URL" in
        http://*|https://*|git://*|git@*)
            printf 'CYBRA_GIT_REMOTE=%s\n' "$URL" > "$HOME/.cybra_remote.env"
            chmod 600 "$HOME/.cybra_remote.env"
            echo "saved"
            echo "test: cybra backup"
            ;;
        *) echo "invalid URL"; exit 1 ;;
    esac
}
git_status(){
    V="$HOME/.cybra_vault"
    [ -d "$V/.git" ] || { echo "no git vault yet (run: cybra backup)"; return; }
    git -C "$V" remote -v
    echo
    git -C "$V" log --oneline -5 2>/dev/null || echo "(no commits)"
    echo
    echo "snapshot.tar.gz:"; ls -la "$V/snapshot.tar.gz" 2>/dev/null || echo "(none)"
}
git_pull(){
    V="$HOME/.cybra_vault"
    [ -f "$HOME/.cybra_remote.env" ] || { echo "no remote"; return 1; }
    . "$HOME/.cybra_remote.env"
    [ -n "${CYBRA_GIT_REMOTE:-}" ] || { echo "no URL"; return 1; }
    command -v git >/dev/null 2>&1 || { echo "install git"; return 1; }
    if [ ! -d "$V/.git" ]; then
        rm -rf "$V"; git clone "$CYBRA_GIT_REMOTE" "$V" 2>&1 | tail -5
    else
        git -C "$V" pull --rebase 2>&1 | tail -5
    fi
    [ -f "$V/snapshot.tar.gz" ] && \
        { echo "restoring..."; tar xzf "$V/snapshot.tar.gz" -C "$HOME"; chmod +x "$ROOT"/*.sh 2>/dev/null; echo "restored"; }
}
repair(){ "$ROOT/cybra_heal.sh"; }
watch(){
    while true; do
        clear
        status_show
        echo
        echo "--- press Ctrl+C to exit ---"
        sleep 5
    done
}

case "$cmd" in
    ""|start|up|run)  start_all ;;
    stop|down)        stop_all ;;
    status|st)        status_show ;;
    heal|fix|repair)  repair ;;
    backup|bk)        "$ROOT/cybra_backup_push.sh" ;;
    restore|pull)     exec "$HOME/.cybra_bootstrap.sh" --force ;;
    git-status)       git_status ;;
    git-pull)         git_pull ;;
    setup-remote)     setup_remote ;;
    watch)            watch ;;
    logs)             tail -f "$ROOT/logs/cybra_master.log" ;;
    help|-h|--help)
        cat <<EOF
cybra commands:
  cybra               start all
  cybra stop          stop all
  cybra status        status
  cybra watch         live status (loop)
  cybra heal/repair   self-repair
  cybra backup        snapshot + git push
  cybra restore       restore from snapshot
  cybra git-status    show git vault
  cybra git-pull      pull + restore from git
  cybra setup-remote  configure git URL
  cybra logs          tail master log
EOF
        ;;
    *) echo "unknown: $cmd (try: cybra help)"; exit 1 ;;
esac
CLI
chmod +x "$PREFIX_BIN/cybra"
bash -n "$PREFIX_BIN/cybra" && ok "CLI" || er "CLI syntax"

# alias @cybra
grep -q "alias @cybra=" "$HOME/.bashrc" 2>/dev/null || \
    echo "alias @cybra='cybra'" >> "$HOME/.bashrc"
ok "alias @cybra"

# ============================================================
# 8. boot hook
# ============================================================
stp "8. Boot hook"
cat > "$BOOT" <<'BT'
#!/data/data/com.termux/files/usr/bin/bash
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock >/dev/null 2>&1 || true
[ -x "$HOME/.cybra_bootstrap.sh" ] && "$HOME/.cybra_bootstrap.sh" >> "$HOME/.cybra_bootstrap.log" 2>&1
P="$HOME/CYBRA/control/cybra_master.pid"
if [ -f "$P" ]; then
    X=$(cat "$P" 2>/dev/null || true)
    [ -n "$X" ] && kill -0 "$X" 2>/dev/null && exit 0
fi
[ -x "$HOME/CYBRA/cybra_master_start.sh" ] && \
    nohup "$HOME/CYBRA/cybra_master_start.sh" >> "$HOME/CYBRA/logs/cybra_boot.log" 2>&1 &
BT
chmod +x "$BOOT"
bash -n "$BOOT" && ok "boot" || er "boot syntax"

# ============================================================
# 9. Git setup (interactive, optional)
# ============================================================
stp "9. Git remote"
if [ ! -f "$ENVF" ]; then
    echo "  Git remote не налаштовано."
    echo "  Хочеш зараз? (Enter = пропустити)"
    printf 'URL: '
    IFS= read -r URL
    URL=$(printf '%s' "$URL" | tr -d '\r\n')
    if [ -n "$URL" ]; then
        case "$URL" in
            http://*|https://*|git://*|git@*)
                printf 'CYBRA_GIT_REMOTE=%s\n' "$URL" > "$ENVF"
                chmod 600 "$ENVF"
                ok "saved: $ENVF"
                ;;
            *) er "invalid URL — skipped" ;;
        esac
    else
        ok "skipped"
    fi
else
    ok "already configured"
fi

# ============================================================
# 10. Ensure snapshot
# ============================================================
stp "10. Snapshot"
"$ROOT/cybra_backup_push.sh" >/dev/null 2>&1
SZ=$(wc -c < "$SNAP_DIR/latest.tar.gz" 2>/dev/null || echo 0)
[ "$SZ" -gt 1000 ] && ok "snapshot: $SZ bytes" || er "snapshot missing"
N=$(find "$SNAP_DIR" -maxdepth 1 -type f -name 'cybra_*.tar.gz' | wc -l)
[ "$N" -eq 1 ] && ok "rotation OK (1 file)" || er "rotation: $N files"

# ============================================================
# 11. Restart all
# ============================================================
stp "11. Restart"
cybra stop 2>/dev/null || true
sleep 2
cybra start
sleep 6

# ============================================================
# 12. Verify
# ============================================================
stp "12. Verify"
cybra status

echo
echo "--- cybra commands ---"
"$PREFIX_BIN/cybra" help

echo
echo "============================================================"
echo "MEGA FINAL COMPLETE"
echo "============================================================"
echo "cybra status | cybra watch | cybra heal | cybra backup"
echo "cybra setup-remote | cybra git-status | cybra git-pull"
echo "============================================================"
