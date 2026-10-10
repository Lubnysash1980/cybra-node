#!/data/data/com.termux/files/usr/bin/bash
DP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB="$DP_ROOT/data/disputes.db"
mkdir -p "$DP_ROOT/data"
touch "$DB"

# Формат: DISPUTE_ID|CONTRACT_ID|OPENED_BY|REASON|ARBITER|VOTE_BUYER|VOTE_SELLER|VOTE_ARBITER|STATE|OPENED_AT|CLOSED_AT

dp_open() {
    local cid="$1" by="$2" reason="$3" arbiter="${4:-auto}"
    [ -z "$cid" ] || [ -z "$by" ] && { echo "ERR: cid+by required"; return 1; }
    local did="DP-$(date -u +%Y%m%d%H%M%S)-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
    printf '%s|%s|%s|%s|%s|PENDING|PENDING|PENDING|OPEN|%s|\n' \
        "$did" "$cid" "$by" "$reason" "$arbiter" "$(date -u +%FT%TZ)" >> "$DB"
    echo "$did"
}

dp_vote() {
    local did="$1" voter="$2" vote="$3"
    [ "$vote" = "BUYER" ] || [ "$vote" = "SELLER" ] || [ "$vote" = "REFUND" ] || [ "$vote" = "RELEASE" ] || {
        echo "ERR: vote must be BUYER|SELLER|REFUND|RELEASE"; return 1
    }
    local line
    line="$(grep "^$did|" "$DB")"
    [ -z "$line" ] && { echo "ERR: dispute not found"; return 1; }
    local state="$(echo "$line" | cut -d'|' -f9)"
    [ "$state" != "OPEN" ] && { echo "ERR: dispute $state"; return 1; }

    case "$voter" in
        BUYER|SELLER|ARBITER) ;;
        *) echo "ERR: voter must be BUYER|SELLER|ARBITER"; return 1 ;;
    esac

    local nline
    nline="$(echo "$line" | awk -F'|' -v v="$voter" -v x="$vote" '{
        if (v=="BUYER") $6=x;
        else if (v=="SELLER") $7=x;
        else if (v=="ARBITER") $8=x;
        print $0
    }' OFS='|')"
    sed -i "s|^$line$|$nline|" "$DB"
    echo "OK: vote recorded"
    dp_check "$did"
}

dp_check() {
    local did="$1"
    local line="$(grep "^$did|" "$DB")"
    local vb="$(echo "$line" | cut -d'|' -f6)"
    local vs="$(echo "$line" | cut -d'|' -f7)"
    local va="$(echo "$line" | cut -d'|' -f8)"

    # 2/3 consensus
    local votes_ok=0 result=""
    if [ "$vb" = "$vs" ] && [ "$vb" != "PENDING" ]; then
        votes_ok=2; result="$vb"
    fi
    if [ "$va" != "PENDING" ] && [ "$votes_ok" -ge 2 ]; then
        result="$va"  # arbiter breaks tie
    elif [ "$va" = "$vb" ] || [ "$va" = "$vs" ]; then
        votes_ok=2; result="$va"
    fi

    if [ "$votes_ok" -ge 2 ] && [ -n "$result" ] && [ "$result" != "PENDING" ]; then
        local nline="$(echo "$line" | awk -F'|' -v st="RESOLVED_$result" -v ts="$(date -u +%FT%TZ)" '{ $9=st; $11=ts; print $0 }' OFS='|')"
        sed -i "s|^$line$|$nline|" "$DB"
        echo "RESOLVED: $result"
    fi
}

dp_list() {
    printf '%-30s %-30s %-10s %s\n' "DISPUTE_ID" "CONTRACT" "STATE" "OPENED"
    printf -- '----\n'
    while IFS='|' read -r did cid by reason arb vb vs va state opened closed; do
        [ -z "$did" ] && continue
        printf '%-30s %-30s %-10s %s\n' "$did" "$cid" "$state" "$opened"
    done < "$DB"
}

dp_show() {
    local did="$1"
    grep "^$did|" "$DB" | while IFS='|' read -r a b c d e f g h i j k; do
        echo "DISPUTE_ID: $a"
        echo "CONTRACT:   $b"
        echo "OPENED_BY:  $c"
        echo "REASON:     $d"
        echo "ARBITER:    $e"
        echo "VOTE_BUYER: $f"
        echo "VOTE_SELLER:$g"
        echo "VOTE_ARB:   $h"
        echo "STATE:      $i"
        echo "OPENED:     $j"
        echo "CLOSED:     $k"
    done
}
