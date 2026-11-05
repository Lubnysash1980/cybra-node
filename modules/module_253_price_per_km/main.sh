#!/data/data/com.termux/files/usr/bin/bash
# module_253: price_per_km (price) — taxi_premium
# generated 2026-10-25T23:07:35Z
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-show}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="price_per_km"
MODULE_CAT="price"

CONF="$CYBRA/state/taxi_premium_config.json"
case "$ACTION" in
  offer)
    RID="${1:-}"; AMOUNT="${2:-}"
    [ -z "$RID" ] || [ -z "$AMOUNT" ] && { echo "usage: $0 offer <ride_id> <amount>"; exit 1; }
    redis-cli hset "cybra:taxi:price:negotiate:$RID" "client_offer=$AMOUNT,ts=$(date -u +%FT%TZ)" >/dev/null
    echo "💵 client offer $AMOUNT → $RID"
    ;;
  counter)
    RID="${1:-}"; AMOUNT="${2:-}"
    [ -z "$RID" ] || [ -z "$AMOUNT" ] && { echo "usage: $0 counter <ride_id> <amount>"; exit 1; }
    redis-cli hset "cybra:taxi:price:negotiate:$RID" "driver_ask=$AMOUNT,ts=$(date -u +%FT%TZ)" >/dev/null
    echo "💵 driver counter $AMOUNT → $RID"
    ;;
  accept)
    RID="${1:-}"; WHO="${2:-client}"
    [ -z "$RID" ] && exit 1
    redis-cli hset "cybra:taxi:price:negotiate:$RID" "accepted_by=$WHO,at=$(date -u +%FT%TZ)" >/dev/null
    echo "✅ $RID accepted by $WHO"
    ;;
  per_km)
    WHO="${1:-client}"; PRICE="${2:-}"
    [ -z "$PRICE" ] && { echo "usage: $0 per_km <client|driver> <price>"; exit 1; }
    redis-cli hset "cybra:taxi:price:perkm" "$WHO" "$PRICE" >/dev/null
    echo "✅ per-km [$WHO]: $PRICE"
    ;;
  show)
    RID="${1:-}"
    if [ -n "$RID" ]; then
      echo "════ negotiate $RID ════"
      redis-cli hgetall "cybra:taxi:price:negotiate:$RID" 2>/dev/null | paste - -
    else
      echo "════ per_km ════"
      redis-cli hgetall cybra:taxi:price:perkm 2>/dev/null | paste - -
    fi
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 offer <ride> <amt> | counter <ride> <amt> | accept <ride> [who] | per_km <who> <price> | show [ride]"
    ;;
esac
