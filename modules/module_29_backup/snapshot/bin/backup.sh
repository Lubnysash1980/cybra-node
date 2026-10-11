#!/data/data/com.termux/files/usr/bin/bash
BK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL="$BK_ROOT/data/local"
mkdir -p "$LOCAL"

bk_local() {
    local stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    local file="$LOCAL/cybra_${stamp}.tar.gz"
    tar -czf "$file" \
        -C "$HOME" \
        --exclude='CYBRA/backups' \
        --exclude='CYBRA/**/node_modules' \
        --exclude='CYBRA/git_module/.git' \
        --exclude='CYBRA/logs' \
        CYBRA 2>/dev/null
    sha256sum "$file" > "${file}.sha256"
    echo "OK: $file"
    du -h "$file"
    # ротація 7 останніх
    ls -t "$LOCAL"/*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
    ls -t "$LOCAL"/*.tar.gz.sha256 2>/dev/null | tail -n +8 | xargs -r rm -f
}

bk_cloud() {
    local remote="${1:-gdrive}"
    if ! command -v rclone >/dev/null 2>&1; then
        echo "ERR: rclone not installed"
        echo "Run: pkg install rclone"
        return 1
    fi
    if ! rclone listremotes 2>/dev/null | grep -q "^${remote}:"; then
        echo "ERR: remote '$remote' not configured"
        echo "Run: rclone config"
        return 1
    fi
    local latest="$(ls -t "$LOCAL"/*.tar.gz 2>/dev/null | head -1)"
    [ -z "$latest" ] && { echo "ERR: no local backup"; return 1; }
    rclone copy "$latest" "${remote}:CYBRA-Backups/" && \
    rclone copy "${latest}.sha256" "${remote}:CYBRA-Backups/" && \
        echo "OK: uploaded $(basename "$latest")"
}

bk_list() {
    printf 'LOCAL BACKUPS:\n'
    ls -lh "$LOCAL"/*.tar.gz 2>/dev/null | tail -10
    printf '\nRCLONE REMOTES:\n'
    rclone listremotes 2>/dev/null || echo "  (rclone missing)"
}

bk_restore() {
    local archive="$1"
    [ -f "$archive" ] || { echo "ERR: file not found"; return 1; }
    echo "Verifying..."
    sha256sum -c "${archive}.sha256" 2>/dev/null || echo "WARN: hash check failed"
    echo "Extracting to $HOME/CYBRA_RESTORE_$(date +%s)..."
    local dir="$HOME/CYBRA_RESTORE_$(date +%s)"
    mkdir -p "$dir"
    tar -xzf "$archive" -C "$dir"
    echo "OK: $dir"
}

bk_auto() {
    bk_local
    bk_cloud gdrive 2>/dev/null || true
}
