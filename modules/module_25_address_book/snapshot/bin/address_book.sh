#!/data/data/com.termux/files/usr/bin/bash
AB_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="$AB_ROOT/data/addresses.db"
HIST="$AB_ROOT/data/history.db"
mkdir -p "$AB_ROOT/data"
[ -f "$DB" ] || touch "$DB"
[ -f "$HIST" ] || touch "$HIST"

ab_add() {
    local name="$1" addr="$2" tag="${3:-user}"
    [ -z "$name" ] || [ -z "$addr" ] && { echo "ERR: name+addr"; return 1; }
    [[ "$addr" =~ ^0x[a-fA-F0-9]{40}$ ]] || { echo "ERR: bad addr"; return 1; }
    grep -q "|$addr|" "$DB" 2>/dev/null && { echo "ERR: addr exists"; return 1; }
    printf '%s|%s|%s|%s\n' "$name" "$addr" "$tag" "$(date -u +%FT%TZ)" >> "$DB"
    printf 'ADD|%s|%s|%s\n' "$name" "$addr" "$(date -u +%FT%TZ)" >> "$HIST"
    echo "OK: $name"
}

ab_remove() {
    local name="$1"
    [ -z "$name" ] && return 1
    grep -v "^$name|" "$DB" > "$DB.tmp" && mv "$DB.tmp" "$DB"
    printf 'RM|%s||%s\n' "$name" "$(date -u +%FT%TZ)" >> "$HIST"
    echo "OK"
}

ab_list() {
    printf '%-24s %-45s %s\n' "NAME" "ADDRESS" "TAG"
    printf -- '----\n'
    while IFS='|' read -r n a t ts; do
        printf '%-24s %-45s %s\n' "$n" "$a" "$t"
    done < "$DB"
}

ab_get() {
    local name="$1"
    grep "^$name|" "$DB" | head -1 | cut -d'|' -f2
}

ab_find_by_addr() {
    local addr="$1"
    grep "|$addr|" "$DB" | head -1 | cut -d'|' -f1
}

ab_history() {
    tail -30 "$HIST"
}

ab_use() {
    local name="$1" cid="$2"
    printf 'USE|%s|%s|%s\n' "$name" "$cid" "$(date -u +%FT%TZ)" >> "$HIST"
}

ab_stats() {
    printf 'total:    %s\n' "$(wc -l < "$DB")"
    printf 'buyers:   %s\n' "$(grep -c '|buyer|' "$DB" 2>/dev/null || echo 0)"
    printf 'sellers:  %s\n' "$(grep -c '|seller|' "$DB" 2>/dev/null || echo 0)"
    printf 'history:  %s\n' "$(wc -l < "$HIST")"
}
