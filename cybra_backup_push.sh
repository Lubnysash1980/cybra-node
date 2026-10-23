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
