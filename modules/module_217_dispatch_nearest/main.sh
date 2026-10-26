#!/data/data/com.termux/files/usr/bin/bash
<<<<<<< HEAD
# taxi module_217: dispatch_nearest (dispatch)
=======
>>>>>>> c0d6c45c7d164ae4ce146ebdd21942e9c1bda593
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/taxi_217.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
<<<<<<< HEAD
err() { log "ERR: $*"; echo "❌ $*" >&2; return 1; }
trap 'err "line $LINENO"' ERR
ACTION="${1:-find}"; shift $(( $# > 0 ? 1 : 0 ))
log "START dispatch_nearest action=$ACTION"

case "$ACTION" in
  add|create|register|schedule|book)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id> [value]"; exit 1; }
    ID="$1"; VAL="${2:-$(date +%s)}"
    redis-cli hset "cybra:taxi:dispatch:data" "$ID" "$VAL" >/dev/null
    echo "✅ dispatch: $ID registered" ;;
  list|history|show|status)
    N=$(redis-cli hlen "cybra:taxi:dispatch:data" 2>/dev/null || echo 0)
    echo "════ taxi dispatch: dispatch_nearest (module_217) ════"
=======
ACTION="${1:-find}"; shift $(( $# > 0 ? 1 : 0 ))
log "START dispatch_nearest action=$ACTION args=$#"
case "$ACTION" in
  create|register|add|book|schedule)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id> [val]"; exit 1; }
    redis-cli hset "cybra:taxi:dispatch:data" "$1" "${2:-$(date +%s)}" >/dev/null
    echo "✅ dispatch: $1" ;;
  list|status|show|history)
    N=$(redis-cli hlen "cybra:taxi:dispatch:data" 2>/dev/null || echo 0)
    echo "════ taxi dispatch: dispatch_nearest ════"
>>>>>>> c0d6c45c7d164ae4ce146ebdd21942e9c1bda593
    echo "  items: $N"
    [ "$N" -gt 0 ] && redis-cli hgetall "cybra:taxi:dispatch:data" | paste - - | head -20 | sed 's/^/  /' ;;
  cancel|delete|remove)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id>"; exit 1; }
    redis-cli hdel "cybra:taxi:dispatch:data" "$1" >/dev/null
    echo "✅ cancelled: $1" ;;
<<<<<<< HEAD
  estimate|calc|score|forecast|optimize|dispatch)
    echo "🧠 dispatch_nearest: AI-режим"
    echo "  args: $*"
    echo "  hint: реагує через AI (cybra_local_ai.sh), fallback redis" ;;
  *)
    echo "════ taxi dispatch_nearest (module_217) ════"
    echo "  action: $ACTION  category: dispatch"
    echo "  hint: $0 create|list|cancel <id>" ;;
esac
rc=$?; log "DONE rc=$rc"; exit $rc
=======
  estimate|calc|score|forecast|optimize|dispatch|chat|resolve)
    echo "🧠 dispatch_nearest (AI) args: $*" ;;
  *) echo "════ taxi dispatch_nearest ════"; echo "  hint: $0 create|list|cancel <id>" ;;
esac
exit $?
>>>>>>> c0d6c45c7d164ae4ce146ebdd21942e9c1bda593
