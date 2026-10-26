#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/taxi_222.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
ACTION="${1:-refund}"; shift $(( $# > 0 ? 1 : 0 ))
log "START ride_refund action=$ACTION args=$#"
case "$ACTION" in
  create|register|add|book|schedule)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id> [val]"; exit 1; }
    redis-cli hset "cybra:taxi:payment:data" "$1" "${2:-$(date +%s)}" >/dev/null
    echo "✅ payment: $1" ;;
  list|status|show|history)
    N=$(redis-cli hlen "cybra:taxi:payment:data" 2>/dev/null || echo 0)
    echo "════ taxi payment: ride_refund ════"
    echo "  items: $N"
    [ "$N" -gt 0 ] && redis-cli hgetall "cybra:taxi:payment:data" | paste - - | head -20 | sed 's/^/  /' ;;
  cancel|delete|remove)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id>"; exit 1; }
    redis-cli hdel "cybra:taxi:payment:data" "$1" >/dev/null
    echo "✅ cancelled: $1" ;;
  estimate|calc|score|forecast|optimize|dispatch|chat|resolve)
    echo "🧠 ride_refund (AI) args: $*" ;;
  *) echo "════ taxi ride_refund ════"; echo "  hint: $0 create|list|cancel <id>" ;;
esac
exit $?
