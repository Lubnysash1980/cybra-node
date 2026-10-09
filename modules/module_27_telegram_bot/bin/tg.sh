#!/data/data/com.termux/files/usr/bin/bash
TG_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$TG_ROOT/state/config.env"
LOG="$TG_ROOT/data/notifications.log"
mkdir -p "$TG_ROOT/data"
touch "$LOG"

[ -f "$CONF" ] && source "$CONF"

tg_send() {
    local msg="$1"
    [ "$TG_ENABLED" != "TRUE" ] && { echo "ERR: tg disabled"; return 1; }
    [ -z "$TG_BOT_TOKEN" ] && { echo "ERR: no token"; return 1; }
    [ -z "$TG_CHAT_ID" ] && { echo "ERR: no chat_id"; return 1; }

    local resp
    resp="$(curl -sS -X POST \
        "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TG_CHAT_ID}" \
        --data-urlencode "text=${msg}" \
        -d "parse_mode=Markdown" \
        --max-time 15 2>/dev/null)"

    printf '%s | SEND | %s | %s\n' \
        "$(date -u +%FT%TZ)" "$(printf '%s' "$msg" | head -c 60)" \
        "$(printf '%s' "$resp" | grep -o '"ok":[a-z]*')" >> "$LOG"

    printf '%s' "$resp" | grep -q '"ok":true' && echo "OK" || echo "FAIL: $resp"
}

tg_notify_contract_created() {
    local cid="$1"
    tg_send "🆕 Contract *$cid* created"
}

tg_notify_confirmation() {
    local cid="$1" role="$2"
    tg_send "✅ *$role* confirmed for *$cid*"
}

tg_notify_refund() {
    local cid="$1" amt="$2"
    tg_send "💸 Refund *$amt* for *$cid*"
}

tg_notify_timeout() {
    local cid="$1"
    tg_send "⏰ Timeout warning: *$cid* (48h left)"
}

tg_test() {
    tg_send "🧪 CYBRA test at $(date -u +%FT%TZ)"
}

tg_log() {
    tail -20 "$LOG"
}

tg_set_token() {
    local token="$1"
    sed -i "s|^TG_BOT_TOKEN=.*|TG_BOT_TOKEN=$token|" "$CONF"
    echo "OK"
}

tg_set_chat() {
    local chat="$1"
    sed -i "s|^TG_CHAT_ID=.*|TG_CHAT_ID=$chat|" "$CONF"
    sed -i "s|^TG_ENABLED=.*|TG_ENABLED=TRUE|" "$CONF"
    echo "OK"
}
