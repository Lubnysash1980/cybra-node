#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/autorevive.log"
INV="$CYBRA/state/process-inventory.json"
mkdir -p "$CYBRA/logs" "$CYBRA/state" "$CYBRA/.cache"
log(){ echo "[$(date '+%T')] $*" | tee -a "$LOG"; }

scan(){
    local tmp="$CYBRA/.cache/scan.raw"; : > "$tmp"
    for f in ~/.pm2/dump.pm2 ~/.pm2/dump.pm2.* \
             ~/CYBRA.old.*/recovery/*.pm2 \
             ~/CYBRA.old.*/snapshots/*/pm2/dump.pm2; do
        [ -f "$f" ] || continue
        jq -r '.[]? | select(.name and .pm_exec_path) |
            [.name, .pm_exec_path, (.exec_interpreter // "none")] | @tsv' "$f" 2>/dev/null >> "$tmp"
    done
    # унікальні за name (останній = найновіший)
    tac "$tmp" | awk -F'\t' '!seen[$1]++' | tac | sort -u -k1,1 > "$CYBRA/.cache/scan.uniq"
    wc -l < "$CYBRA/.cache/scan.uniq"
}

ensure_file(){
    local path="$1"
    [ -f "$path" ] && return 0
    cd "$CYBRA" 2>/dev/null || return 1
    # git
    local commit; commit=$(git log --all --oneline -- "$path" 2>/dev/null | head -1 | awk '{print $1}')
    if [ -n "$commit" ]; then
        git checkout "$commit" -- "$path" 2>/dev/null && [ -f "$path" ] && return 0
    fi
    # .old
    local rel="${path#$HOME/CYBRA/}"
    for old in ~/CYBRA.old.*; do
        [ -f "$old/$rel" ] && {
            mkdir -p "$(dirname "$path")"
            cp "$old/$rel" "$path" && chmod +x "$path" 2>/dev/null
            return 0
        }
    done
    return 1
}

start_one(){
    local name="$1" exec="$2" interp="$3"
    if pm2 jlist 2>/dev/null | jq -e --arg n "$name" \
        '.[] | select(.name==$n and .pm2_env.status=="online")' >/dev/null 2>&1; then
        return 0
    fi
    if ! ensure_file "$exec"; then
        log "  ❌ $name: file not found ($exec)"
        return 1
    fi
    local flag=""
    case "$interp" in
        python3) flag="--interpreter python3" ;;
        node)    flag="--interpreter node" ;;
        bash)    flag="--interpreter bash" ;;
    esac
    if pm2 describe "$name" >/dev/null 2>&1; then
        pm2 restart "$name" >/dev/null 2>&1
    else
        pm2 start "$exec" --name "$name" $flag >/dev/null 2>&1
    fi
    log "  ✅ $name ($interp)"
}

revive(){
    local total; total=$(scan)
    log "═══ AUTOREVIVE ═══ знайдено $total процесів"
    local ok=0 skip=0
    while IFS=$'\t' read -r name exec interp; do
        [ -z "$name" ] && continue
        [ "$name" = "PM2" ] && continue
        if start_one "$name" "$exec" "$interp"; then
            ok=$((ok+1))
        else
            skip=$((skip+1))
        fi
    done < "$CYBRA/.cache/scan.uniq"
    pm2 save --force >/dev/null 2>&1
    log "═══ DONE ═══ online=$ok skip=$skip"
    cp "$CYBRA/.cache/scan.uniq" "$INV.tmp"
    jq -Rn '[inputs | split("\t") | {name:.[0], exec:.[1], interp:.[2]}]' \
        < "$INV.tmp" > "$INV" && rm -f "$INV.tmp"
    pm2 list
}

case "${1:-revive}" in
    scan)    scan ;;
    revive)  revive ;;
    list)    cat "$INV" 2>/dev/null | jq -r '.[] | "\(.name)\t\(.interp)\t\(.exec)"' | column -t -s $'\t' ;;
    daemon)
        while true; do revive; sleep "${2:-300}"; done ;;
    *) echo "usage: $0 {scan|revive|list|daemon [interval]}" ;;
esac
