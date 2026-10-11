#!/data/data/com.termux/files/usr/bin/bash
WH_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$WH_ROOT/state/webhooks.env"
LOG="$WH_ROOT/data/webhook.log"
mkdir -p "$WH_ROOT/data"
[ -f "$CONF" ] && source "$CONF"
touch "$LOG"

wh_add() {
    local name="$1" url="$2" events="${3:-*}"
    echo "WEBHOOK_${name}=${url}|${events}" >> "$CONF"
    echo "OK: $name"
}

wh_remove() {
    local name="$1"
    sed -i "/^WEBHOOK_${name}=/d" "$CONF"
    echo "OK"
}

wh_list() {
    grep '^WEBHOOK_' "$CONF" 2>/dev/null | while IFS='=' read -r k v; do
        local name="${k#WEBHOOK_}"
        local url="$(echo "$v" | cut -d'|' -f1)"
        local ev="$(echo "$v" | cut -d'|' -f2)"
        printf '  %-20s %s [%s]\n' "$name" "$url" "$ev"
    done
}

wh_fire() {
    local event="$1" payload="$2"
    [ "$WEBHOOK_ENABLED" != "TRUE" ] && return 0
    grep '^WEBHOOK_' "$CONF" 2>/dev/null | while IFS='=' read -r k v; do
        local name="${k#WEBHOOK_}"
        local url="$(echo "$v" | cut -d'|' -f1)"
        local events="$(echo "$v" | cut -d'|' -f2)"
        case "$events" in
            *"$event"*|"*")
                local body="{\"event\":\"$event\",\"ts\":\"$(date -u +%FT%TZ)\",\"data\":$payload}"
                local code
                code="$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$url" \
                    -H "Content-Type: application/json" \
                    -d "$body" --max-time 10 2>/dev/null)"
                printf '%s | %s | %s | %s\n' "$(date -u +%FT%TZ)" "$name" "$event" "$code" >> "$LOG"
                ;;
        esac
    done
}

wh_log() {
    tail -30 "$LOG"
}

wh_test() {
    wh_fire "test" '{"msg":"CYBRA webhook test"}'
    echo "OK: fired"
}
