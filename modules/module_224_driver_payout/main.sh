#!/data/data/com.termux/files/usr/bin/bash
<<<<<<< HEAD
# taxi module_224: driver_payout (payment)
=======
>>>>>>> c0d6c45c7d164ae4ce146ebdd21942e9c1bda593
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/taxi_224.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
<<<<<<< HEAD
err() { log "ERR: $*"; echo "❌ $*" >&2; return 1; }
trap 'err "line $LINENO"' ERR
ACTION="${1:-payout}"; shift $(( $# > 0 ? 1 : 0 ))
log "START driver_payout action=$ACTION"

case "$ACTION" in
  add|create|register|schedule|book)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id> [value]"; exit 1; }
    ID="$1"; VAL="${2:-$(date +%s)}"
    redis-cli hset "cybra:taxi:payment:data" "$ID" "$VAL" >/dev/null
    echo "✅ payment: $ID registered" ;;
  list|history|show|status)
    N=$(redis-cli hlen "cybra:taxi:payment:data" 2>/dev/null || echo 0)
    echo "════ taxi payment: driver_payout (module_224) ════"
=======
ACTION="${1:-payout}"; shift $(( $# > 0 ? 1 : 0 ))
log "START driver_payout action=$ACTION args=$#"
case "$ACTION" in
  create|register|add|book|schedule)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id> [val]"; exit 1; }
    redis-cli hset "cybra:taxi:payment:data" "$1" "${2:-$(date +%s)}" >/dev/null
    echo "✅ payment: $1" ;;
  list|status|show|history)
    N=$(redis-cli hlen "cybra:taxi:payment:data" 2>/dev/null || echo 0)
    echo "════ taxi payment: driver_payout ════"
>>>>>>> c0d6c45c7d164ae4ce146ebdd21942e9c1bda593
    echo "  items: $N"
    if [ "$N" -gt 0 ]; then redis-cli hgetall "cybra:taxi:payment:data" | paste - - | head -20 | sed 's/^/  /'; fi ;;
  cancel|delete|remove)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id>"; exit 1; }
    redis-cli hdel "cybra:taxi:payment:data" "$1" >/dev/null
    echo "✅ cancelled: $1" ;;
<<<<<<< HEAD
  estimate|calc|score|forecast|optimize|dispatch)
    echo "🧠 driver_payout: AI-режим"
    echo "  args: $*"
    echo "  hint: реагує через AI (cybra_local_ai.sh), fallback redis" ;;
  *)
    echo "════ taxi driver_payout (module_224) ════"
    echo "  action: $ACTION  category: payment"
    echo "  hint: $0 create|list|cancel <id>" ;;
esac
rc=$?; log "DONE rc=$rc"; exit $rc
=======
  estimate|calc|score|forecast|optimize|dispatch|chat|resolve)
    echo "🧠 driver_payout (AI) args: $*" ;;
  *) echo "════ taxi driver_payout ════"; echo "  hint: $0 create|list|cancel <id>" ;;
esac
exit $?
>>>>>>> c0d6c45c7d164ae4ce146ebdd21942e9c1bda593
