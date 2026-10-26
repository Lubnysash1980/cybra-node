#!/data/data/com.termux/files/usr/bin/bash
<<<<<<< HEAD
# taxi module_203: ride_history (booking)
=======
>>>>>>> c0d6c45c7d164ae4ce146ebdd21942e9c1bda593
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/taxi_203.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
<<<<<<< HEAD
err() { log "ERR: $*"; echo "❌ $*" >&2; return 1; }
trap 'err "line $LINENO"' ERR
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
log "START ride_history action=$ACTION"

case "$ACTION" in
  add|create|register|schedule|book)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id> [value]"; exit 1; }
    ID="$1"; VAL="${2:-$(date +%s)}"
    redis-cli hset "cybra:taxi:booking:data" "$ID" "$VAL" >/dev/null
    echo "✅ booking: $ID registered" ;;
  list|history|show|status)
    N=$(redis-cli hlen "cybra:taxi:booking:data" 2>/dev/null || echo 0)
    echo "════ taxi booking: ride_history (module_203) ════"
=======
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
log "START ride_history action=$ACTION args=$#"
case "$ACTION" in
  create|register|add|book|schedule)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id> [val]"; exit 1; }
    redis-cli hset "cybra:taxi:booking:data" "$1" "${2:-$(date +%s)}" >/dev/null
    echo "✅ booking: $1" ;;
  list|status|show|history)
    N=$(redis-cli hlen "cybra:taxi:booking:data" 2>/dev/null || echo 0)
    echo "════ taxi booking: ride_history ════"
>>>>>>> c0d6c45c7d164ae4ce146ebdd21942e9c1bda593
    echo "  items: $N"
    if [ "$N" -gt 0 ]; then redis-cli hgetall "cybra:taxi:booking:data" | paste - - | head -20 | sed 's/^/  /'; fi ;;
  cancel|delete|remove)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id>"; exit 1; }
    redis-cli hdel "cybra:taxi:booking:data" "$1" >/dev/null
    echo "✅ cancelled: $1" ;;
<<<<<<< HEAD
  estimate|calc|score|forecast|optimize|dispatch)
    echo "🧠 ride_history: AI-режим"
    echo "  args: $*"
    echo "  hint: реагує через AI (cybra_local_ai.sh), fallback redis" ;;
  *)
    echo "════ taxi ride_history (module_203) ════"
    echo "  action: $ACTION  category: booking"
    echo "  hint: $0 create|list|cancel <id>" ;;
esac
rc=$?; log "DONE rc=$rc"; exit $rc
=======
  estimate|calc|score|forecast|optimize|dispatch|chat|resolve)
    echo "🧠 ride_history (AI) args: $*" ;;
  *) echo "════ taxi ride_history ════"; echo "  hint: $0 create|list|cancel <id>" ;;
esac
exit $?
>>>>>>> c0d6c45c7d164ae4ce146ebdd21942e9c1bda593
