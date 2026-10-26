#!/data/data/com.termux/files/usr/bin/bash
# module_269: ai_assistant (ai) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-ask}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="ai_assistant"
MODULE_CAT="ai"

CONF="$CYBRA/state/taxi_premium_config.json"
case "$ACTION" in
  ask)
    Q="$*"
    [ -z "$Q" ] && exit 1
    echo "════ ${MODULE_LABEL}: $Q ════"
    # try local AI first
    LOCAL="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_local_ai.sh"
    if [ -x "$LOCAL" ]; then
      CYBRA_MOD19_ROOT="$CYBRA/modules/module_19_contract_tui_menu" bash "$LOCAL" ask "$Q" 2>/dev/null
    else
      echo "  (offline fallback)"
      echo "  My purpose: help with taxi rides, prices, routes, wallets."
    fi
    ;;
  suggest_price)
    RID="${1:-}"; KM="${2:-5}"
    [ -z "$RID" ] && exit 1
    BASE=$(awk "BEGIN{print $KM * 15}")
    LOW=$(awk "BEGIN{print $BASE * 0.8}")
    HIGH=$(awk "BEGIN{print $BASE * 1.2}")
    echo "════ price suggestion: $RID, ${KM}km ════"
    echo "  range: $LOW - $HIGH (base $BASE)"
    redis-cli hset "cybra:taxi:price:suggest:$RID" "low=$LOW,base=$BASE,high=$HIGH,km=$KM" >/dev/null
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 ask <question> | suggest_price <ride> <km>"
    ;;
esac
