#!/data/data/com.termux/files/usr/bin/bash
# taxi module_222: ride_refund (payment)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/taxi_222.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
err() { log "ERR: $*"; echo "❌ $*" >&2; return 1; }
trap 'err "line $LINENO"' ERR
ACTION="${1:-refund}"; shift $(( $# > 0 ? 1 : 0 ))
log "START ride_refund action=$ACTION"

case "$ACTION" in
  add|create|register|schedule|book)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id> [value]"; exit 1; }
    ID="$1"; VAL="${2:-$(date +%s)}"
    redis-cli hset "cybra:taxi:payment:data" "$ID" "$VAL" >/dev/null
    echo "✅ payment: $ID registered" ;;
  list|history|show|status)
    N=$(redis-cli hlen "cybra:taxi:payment:data" 2>/dev/null || echo 0)
    echo "════ taxi payment: ride_refund (module_222) ════"
    echo "  items: $N"
    [ "$N" -gt 0 ] && redis-cli hgetall "cybra:taxi:payment:data" | paste - - | head -20 | sed 's/^/  /' ;;
  cancel|delete|remove)
    [ $# -lt 1 ] && { echo "usage: $0 $ACTION <id>"; exit 1; }
    redis-cli hdel "cybra:taxi:payment:data" "$1" >/dev/null
    echo "✅ cancelled: $1" ;;
  estimate|calc|score|forecast|optimize|dispatch)
    echo "🧠 ride_refund: AI-режим"
    echo "  args: $*"
    echo "  hint: реагує через AI (cybra_local_ai.sh), fallback redis" ;;
  *)
    echo "════ taxi ride_refund (module_222) ════"
    echo "  action: $ACTION  category: payment"
    echo "  hint: $0 create|list|cancel <id>" ;;
esac
rc=$?; log "DONE rc=$rc"; exit $rc
