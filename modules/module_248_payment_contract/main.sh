#!/data/data/com.termux/files/usr/bin/bash
# module_248: payment_contract (payment) — taxi_premium
# generated 2026-10-25T23:07:35Z
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="payment_contract"
MODULE_CAT="payment"

CONF="$CYBRA/state/taxi_premium_config.json"
TOKEN=$(python3 -c "import json;print(json.load(open('$CONF'))['cybra_token'])" 2>/dev/null || echo "0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f")
COMMISSION=$(python3 -c "import json;print(json.load(open('$CONF'))['commission_pct'])" 2>/dev/null || echo 5)
case "$ACTION" in
  instant|transfer)
    FROM="${1:-}"; TO="${2:-}"; AMOUNT="${3:-}"
    [ -z "$FROM" ] || [ -z "$TO" ] || [ -z "$AMOUNT" ] && { echo "usage: $0 instant <from> <to> <amount>"; exit 1; }
    RID="PAY-$(date +%s)"
    redis-cli hset "cybra:taxi:payment:data" "$RID" "from=$FROM,to=$TO,amount=$AMOUNT,status=queued" >/dev/null
    echo "💳 card→card: $FROM → $TO  $AMOUNT"
    echo "  pay_id: $RID  status: queued"
    echo "  ⚠️ Real bank card transfer requires PSP (LiqPay/Fondy/Stripe)"
    ;;
  commission)
    AMOUNT="${1:-}"
    [ -z "$AMOUNT" ] && { echo "usage: $0 commission <ride_amount>"; exit 1; }
    FEE=$(awk "BEGIN{printf \"%.2f\", $AMOUNT * $COMMISSION / 100}")
    NET=$(awk "BEGIN{printf \"%.2f\", $AMOUNT - $FEE}")
    RID="COM-$(date +%s)"
    redis-cli hset "cybra:taxi:commission:data" "$RID" "amount=$AMOUNT,fee=$FEE,net=$NET,token=$TOKEN,status=pending" >/dev/null
    echo "════ commission ${COMMISSION}% ════"
    echo "  ride:   $AMOUNT"
    echo "  fee:    $FEE  →  CYBRA token $TOKEN"
    echo "  driver: $NET"
    echo "  ref:    $RID"
    echo "  ⚠️ On-chain transfer needs wallet + RPC"
    ;;
  contract)
    AMOUNT="${1:-}"; DRIVER="${2:-}"; RIDER="${3:-}"
    [ -z "$AMOUNT" ] && { echo "usage: $0 contract <amount> <driver> <rider>"; exit 1; }
    OUT=$(bash "$CYBRA/bin/cybra_contract_create.sh" "$RIDER" "$DRIVER" "$AMOUNT" "CYBRA" 2>/dev/null)
    [ -z "$OUT" ] && OUT=$(bash "$CYBRA/cybra_contract_cli.sh" create "$RIDER" "$DRIVER" "$AMOUNT" "CYBRA" 2>/dev/null)
    echo "$OUT"
    echo "  📝 Підписати у гаманці: відкрий contract у MetaMask"
    ;;
  list|*)
    echo "════ ${MODULE_LABEL} ════"
    echo "  token:      $TOKEN"
    echo "  commission: ${COMMISSION}%"
    echo "  instant:    $0 instant <from> <to> <amount>"
    echo "  commission: $0 commission <ride_amount>"
    echo "  contract:   $0 contract <amount> <driver> <rider>"
    ;;
esac
