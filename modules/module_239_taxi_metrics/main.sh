#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/taxi_239.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
ACTION="${1:-show}"; shift $(( $# > 0 ? 1 : 0 ))
log "START taxi_metrics action=$ACTION args=$#"
case "$ACTION" in
  create|register|add|book|schedule)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id> [val]"; exit 1; }
    redis-cli hset "cybra:taxi:analytics:data" "$1" "${2:-$(date +%s)}" >/dev/null
    echo "✅ analytics: $1" ;;
  list|status|show|history)
    N=$(redis-cli hlen "cybra:taxi:analytics:data" 2>/dev/null || echo 0)
    echo "════ taxi analytics: taxi_metrics ════"
    echo "  items: $N"
    if [ "$N" -gt 0 ]; then redis-cli hgetall "cybra:taxi:analytics:data" | paste - - | head -20 | sed 's/^/  /'; fi
  cancel|delete|remove)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id>"; exit 1; }
    redis-cli hdel "cybra:taxi:analytics:data" "$1" >/dev/null
    echo "✅ cancelled: $1" ;;
  estimate|calc|score|forecast|optimize|dispatch|chat|resolve)
    echo "🧠 taxi_metrics (AI) args: $*" ;;
  *) echo "════ taxi taxi_metrics ════"; echo "  hint: $0 create|list|cancel <id>" ;;
esac
exit $?
