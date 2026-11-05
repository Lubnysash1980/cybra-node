#!/data/data/com.termux/files/usr/bin/bash
# module_250: wallet_list (wallet) — taxi_premium
# generated 2026-10-25T23:07:35Z
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="wallet_list"
MODULE_CAT="wallet"

case "$ACTION" in
  connect|add)
    ADDR="${1:-}"; ROLE="${2:-rider}"
    [ -z "$ADDR" ] && { echo "usage: $0 connect <address> [rider|driver|both]"; exit 1; }
    redis-cli hset "cybra:taxi:wallet:data" "$ADDR" "role=$ROLE,at=$(date -u +%FT%TZ)" >/dev/null
    echo "👛 connected: $ADDR ($ROLE)"
    ;;
  list)
    echo "════ wallets ════"
    redis-cli hgetall cybra:taxi:wallet:data 2>/dev/null | paste - - | while read a i; do
      echo "  $a  ($i)"
    done
    ;;
  balance)
    ADDR="${1:-}"
    [ -z "$ADDR" ] && { echo "usage: $0 balance <address>"; exit 1; }
    echo "════ balance $ADDR ════"
    echo "  CYBRA: $(redis-cli get "cybra:wallet:$ADDR:cybra" 2>/dev/null || echo 0)"
    echo "  BNB:   $(redis-cli get "cybra:wallet:$ADDR:bnb" 2>/dev/null || echo 0)"
    echo "  ⚠️ On-chain balance: needs RPC (bin/cybra_node.sh)"
    ;;
  remove)
    ADDR="${1:-}"; [ -z "$ADDR" ] && exit 1
    redis-cli hdel cybra:taxi:wallet:data "$ADDR" >/dev/null
    echo "✅ removed: $ADDR"
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 connect <addr> [role] | list | balance <addr> | remove <addr>"
    ;;
esac
