#!/data/data/com.termux/files/usr/bin/bash
# module_280: payment_system — IBAN, картки (маска), історія платежів
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_280.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }

KEY_METHODS="cybra:payment:methods"
KEY_HISTORY="cybra:payment:history"
KEY_CONFIG="cybra:payment:config"

mask_card() {
  local c="$1"
  c=$(printf '%s' "$c" | tr -d ' -')
  local last4="${c: -4}"
  echo "**** **** **** $last4"
}

valid_iban() {
  local i="$1"
  [[ "$i" =~ ^[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}$ ]]
}

ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
log "START action=$ACTION"

case "$ACTION" in
  init)
    # init --iban UA... --card 4149... --holder "Ім'я"
    IBAN=""; CARD=""; HOLDER=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --iban) IBAN="$2"; shift 2 ;;
        --card) CARD="$2"; shift 2 ;;
        --holder) HOLDER="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -n "$IBAN" ] && redis-cli hset "$KEY_CONFIG" iban "$IBAN" >/dev/null
    [ -n "$CARD" ] && redis-cli hset "$KEY_CONFIG" card_masked "$(mask_card "$CARD")" >/dev/null
    [ -n "$HOLDER" ] && redis-cli hset "$KEY_CONFIG" holder "$HOLDER" >/dev/null
    redis-cli hset "$KEY_CONFIG" initialized "$(date -u +%FT%TZ)" >/dev/null
    echo "✅ payment system initialized"
    redis-cli hgetall "$KEY_CONFIG" | paste - - | sed 's/^/  /'
    ;;

  show)
    echo "════ PAYMENT SYSTEM ════"
    redis-cli hgetall "$KEY_CONFIG" | paste - - | sed 's/^/  /'
    ;;

  add)
    # add <label> [--iban ...] [--card ...] [--note ...]
    [ $# -lt 1 ] && { echo "usage: $0 add <label> [--iban X --card Y --note Z]"; exit 1; }
    LABEL="$1"; shift
    IBAN=""; CARD=""; NOTE=""; WALLET=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --iban)   IBAN="$2"; shift 2 ;;
        --card)   CARD="$2"; shift 2 ;;
        --wallet) WALLET="$2"; shift 2 ;;
        --note)   NOTE="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -z "$IBAN" ] && [ -z "$CARD" ] && [ -z "$WALLET" ] && { echo "❌ потрібен --iban, --card, або --wallet"; exit 1; }
    [ -n "$IBAN" ] && ! valid_iban "$IBAN" && { echo "❌ невалідний IBAN"; exit 1; }
    DATA=""
    [ -n "$IBAN" ] && DATA="iban=$IBAN"
    [ -n "$CARD" ] && DATA="${DATA:+$DATA,}card_masked=$(mask_card "$CARD")"
    [ -n "$WALLET" ] && DATA="${DATA:+$DATA,}wallet=$WALLET"
    [ -n "$NOTE" ] && DATA="${DATA:+$DATA,}note=$NOTE"
    DATA="$DATA,added=$(date -u +%FT%TZ)"
    redis-cli hset "$KEY_METHODS" "$LABEL" "$DATA" >/dev/null
    echo "✅ $LABEL: $DATA"
    ;;

  list|status)
    N=$(redis-cli hlen "$KEY_METHODS" 2>/dev/null || echo 0)
    echo "════ payment_system ════"
    echo "  methods: $N"
    if [ "$N" -gt 0 ]; then
      redis-cli hgetall "$KEY_METHODS" | paste - - | sed 's/^/  /'
    fi
    ;;

  delete|rm)
    [ $# -lt 1 ] && { echo "usage: $0 delete <label>"; exit 1; }
    redis-cli hdel "$KEY_METHODS" "$1" >/dev/null
    echo "✅ deleted: $1"
    ;;

  pay)
    # pay <label> <amount> <to>
    [ $# -lt 3 ] && { echo "usage: $0 pay <label> <amount> <to>"; exit 1; }
    LABEL="$1"; AMOUNT="$2"; TO="$3"
    M=$(redis-cli hget "$KEY_METHODS" "$LABEL")
    [ -z "$M" ] && { echo "❌ метод '$LABEL' не знайдено"; exit 1; }
    REF="PAY-$(date +%s)-$RANDOM"
    ENTRY="$REF|$LABEL|$AMOUNT|$TO|pending|$(date -u +%FT%TZ)"
    echo "$ENTRY" | redis-cli -x rpush "$KEY_HISTORY" >/dev/null
    # push event для парламенту
    TASK="{\"type\":\"taxi_event\",\"action\":\"payment.created\",\"ref\":\"$REF\",\"amount\":\"$AMOUNT\",\"to\":\"$TO\",\"method\":\"$LABEL\"}"
    printf '%s' "$TASK" | redis-cli -x rpush cybra:parliament:queue >/dev/null
    echo "✅ $REF: $AMOUNT → $TO (via $LABEL)"
    ;;

  history)
    N=$(redis-cli llen "$KEY_HISTORY" 2>/dev/null || echo 0)
    echo "════ payment history ($N) ════"
    redis-cli lrange "$KEY_HISTORY" -20 -1 2>/dev/null | sed 's/^/  /'
    ;;

  *)
    echo "════ module_280: payment_system ════"
    echo "  actions:"
    echo "    init --iban UA.. --card 4149.. --holder 'Name'"
    echo "    show"
    echo "    add <label> [--iban X] [--card Y] [--wallet 0x..] [--note Z]"
    echo "    list"
    echo "    delete <label>"
    echo "    pay <label> <amount> <to>"
    echo "    history"
    ;;
esac
rc=$?; log "DONE rc=$rc"; exit $rc
