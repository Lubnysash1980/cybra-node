#!/data/data/com.termux/files/usr/bin/bash
# module_272: app_metrics (metrics) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-today}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="app_metrics"
MODULE_CAT="metrics"

case "$ACTION" in
  record)
    KEY="${1:-}"; VAL="${2:-1}"
    [ -z "$KEY" ] && exit 1
    redis-cli hincrby "cybra:taxi:metrics:$(date +%Y%m%d)" "$KEY" "$VAL" >/dev/null
    echo "📊 $KEY +$VAL"
    ;;
  today)
    echo "════ metrics $(date +%Y%m%d) ════"
    redis-cli hgetall "cybra:taxi:metrics:$(date +%Y%m%d)" 2>/dev/null | paste - -
    ;;
  week)
    echo "════ metrics last 7 days ════"
    for i in 0 1 2 3 4 5 6; do
      D=$(date -d "-$i days" +%Y%m%d 2>/dev/null || date -v-${i}d +%Y%m%d 2>/dev/null)
      N=$(redis-cli hlen "cybra:taxi:metrics:$D" 2>/dev/null || echo 0)
      echo "  $D: $N metrics"
    done
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 record <key> [val] | today | week"
    ;;
esac
