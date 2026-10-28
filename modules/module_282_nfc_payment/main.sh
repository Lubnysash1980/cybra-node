#!/data/data/com.termux/files/usr/bin/bash
# module_282: nfc_payment — NFC tag → wallet, tap-to-pay
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_282.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
ACTION="${1:-help}"; shift $(( $# > 0 ? 1 : 0 ))

KEY_TAGS="cybra:nfc:tags"
KEY_HIST="cybra:nfc:history"

log "START action=$ACTION"

case "$ACTION" in
  register|link)
    [ $# -lt 2 ] && { echo "usage: $0 register <tag_id> <wallet_label>"; exit 1; }
    TAG="$1"; LABEL="$2"
    W=$(redis-cli hget cybra:payment:methods "$LABEL" 2>/dev/null | grep -oE 'wallet=0x[a-fA-F0-9]+' | cut -d= -f2)
    [ -z "$W" ] && { echo "❌ метод '$LABEL' не має wallet"; exit 1; }
    redis-cli hset "$KEY_TAGS" "$TAG" "wallet=$W,label=$LABEL,linked=$(date -u +%FT%TZ)" >/dev/null
    echo "✅ NFC tag '$TAG' → $LABEL ($W)"
    ;;

  pay|tap)
    [ $# -lt 3 ] && { echo "usage: $0 pay <tag_id> <amount> <to_addr>"; exit 1; }
    TAG="$1"; AMT="$2"; TO="$3"
    M=$(redis-cli hget "$KEY_TAGS" "$TAG")
    [ -z "$M" ] && { echo "❌ tag '$TAG' не зареєстровано"; exit 1; }
    W=$(printf '%s' "$M" | grep -oE 'wallet=0x[a-fA-F0-9]+' | cut -d= -f2)
    L=$(printf '%s' "$M" | grep -oE 'label=[^,]+' | cut -d= -f2)
    # делегуємо в token_system
    bash modules/module_281_token_system/main.sh transfer "$L" "$TO" "$AMT"
    ENTRY="$TAG|$W|$TO|$AMT|$(date -u +%FT%TZ)"
    echo "$ENTRY" | redis-cli -x rpush "$KEY_HIST" >/dev/null
    redis-cli rpush cybra:parliament:queue "{\"type\":\"taxi_event\",\"action\":\"nfc.pay\",\"tag\":\"$TAG\",\"to\":\"$TO\",\"amount\":\"$AMT\"}" >/dev/null
    ;;

  list)
    N=$(redis-cli hlen "$KEY_TAGS" 2>/dev/null || echo 0)
    echo "════ NFC tags ($N) ════"
    redis-cli hgetall "$KEY_TAGS" | paste - - | sed 's/^/  /'
    ;;

  unlink|remove)
    [ $# -lt 1 ] && { echo "usage: $0 unlink <tag_id>"; exit 1; }
    redis-cli hdel "$KEY_TAGS" "$1" >/dev/null
    echo "✅ unlinked: $1"
    ;;

  history)
    N=$(redis-cli llen "$KEY_HIST" 2>/dev/null || echo 0)
    echo "════ NFC history ($N) ════"
    redis-cli lrange "$KEY_HIST" -20 -1 2>/dev/null | sed 's/^/  /'
    ;;

  *)
    echo "════ module_282: nfc_payment ════"
    echo "  actions:"
    echo "    register <tag_id> <wallet_label>"
    echo "    pay <tag_id> <amount> <to_addr>"
    echo "    list"
    echo "    unlink <tag_id>"
    echo "    history"
    ;;
esac
rc=$?; log "DONE rc=$rc"; exit $rc
