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
