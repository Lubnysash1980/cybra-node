#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/taxi_232.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
ACTION="${1:-optimize}"; shift $(( $# > 0 ? 1 : 0 ))
log "START ai_route_optimize action=$ACTION args=$#"
case "$ACTION" in
  create|register|add|book|schedule)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id> [val]"; exit 1; }
    redis-cli hset "cybra:taxi:ai:data" "$1" "${2:-$(date +%s)}" >/dev/null
    echo "✅ ai: $1" ;;
  list|status|show|history)
    N=$(redis-cli hlen "cybra:taxi:ai:data" 2>/dev/null || echo 0)
    echo "════ taxi ai: ai_route_optimize ════"
    echo "  items: $N"
    if [ "$N" -gt 0 ]; then redis-cli hgetall "cybra:taxi:ai:data" | paste - - | head -20 | sed 's/^/  /'; fi
  cancel|delete|remove)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id>"; exit 1; }
    redis-cli hdel "cybra:taxi:ai:data" "$1" >/dev/null
    echo "✅ cancelled: $1" ;;
  estimate|calc|score|forecast|optimize|dispatch|chat|resolve)
    echo "🧠 ai_route_optimize (AI) args: $*" ;;
  *) echo "════ taxi ai_route_optimize ════"; echo "  hint: $0 create|list|cancel <id>" ;;
esac
exit $?
