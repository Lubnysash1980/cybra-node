#!/data/data/com.termux/files/usr/bin/bash
AU_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$AU_ROOT/data/audit.log"
CHAIN="$AU_ROOT/data/audit.chain"
mkdir -p "$AU_ROOT/data"
touch "$LOG"

# Append-only + hash chain
au_append() {
    local actor="$1" action="$2" target="$3" data="$4"
    local ts="$(date -u +%FT%TZ)"
    local prev="$(tail -1 "$CHAIN" 2>/dev/null | awk '{print $NF}')"
    [ -z "$prev" ] && prev="GENESIS"

    local payload="${ts}|${actor}|${action}|${target}|${data}|${prev}"
    local hash="$(printf '%s' "$payload" | sha256sum | awk '{print $1}')"
    printf '%s\n' "$payload|$hash" >> "$LOG"
    printf '%s\n' "$hash" >> "$CHAIN"
    echo "$hash"
}

au_verify() {
    local prev="GENESIS"
    local line_no=0
    local ok=1
    while IFS='|' read -r ts actor action target data phash hash; do
        line_no=$((line_no+1))
        local payload="${ts}|${actor}|${action}|${target}|${data}|${prev}"
        local computed="$(printf '%s' "$payload" | sha256sum | awk '{print $1}')"
        if [ "$computed" != "$hash" ]; then
            echo "FAIL at line $line_no"
            ok=0
            break
        fi
        prev="$hash"
    done < "$LOG"
    [ "$ok" -eq 1 ] && echo "OK: $line_no entries verified" || echo "BROKEN"
}

au_show() {
    tail -20 "$LOG"
}

au_stats() {
    printf 'entries: %s\n' "$(wc -l < "$LOG")"
    printf 'size:    %s\n' "$(du -h "$LOG" | cut -f1)"
    printf 'last:    %s\n' "$(tail -1 "$LOG" | cut -d'|' -f1)"
}

au_export_json() {
    local out="$AU_ROOT/data/audit.json"
    printf '[\n' > "$out"
    local first=1
    while IFS='|' read -r ts actor action target data phash hash; do
        [ -z "$ts" ] && continue
        [ "$first" -eq 0 ] && printf ',\n' >> "$out"
        first=0
        printf '{"ts":"%s","actor":"%s","action":"%s","target":"%s","data":"%s","hash":"%s"}' \
            "$ts" "$actor" "$action" "$target" "$data" "$hash" >> "$out"
    done < "$LOG"
    printf '\n]\n' >> "$out"
    echo "OK: $out"
}
