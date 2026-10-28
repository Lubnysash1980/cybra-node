#!/data/data/com.termux/files/usr/bin/bash
# module_036: auto_task_runner (system)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_036.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
trap 'log "ERR line $LINENO"' ERR
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
log "START auto_task_runner action=$ACTION"

case "$ACTION" in
  add|create|register)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name> [value]"; exit 1; fi
    VAL="${2:-$(date +%s)}"
    redis-cli hset "cybra:system:data" "$1" "$VAL" >/dev/null
    echo "✅ system: $1 = $VAL"
    ;;
  list|status|show)
    N=$(redis-cli hlen "cybra:system:data" 2>/dev/null || echo 0)
    echo "════ system (module_036) ════"
    echo "  items: $N"
    if [ "$N" -gt 0 ]; then
      redis-cli hgetall "cybra:system:data" | paste - - | head -20 | sed 's/^/  /'
    fi
    ;;
  delete|remove)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name>"; exit 1; fi
    redis-cli hdel "cybra:system:data" "$1" >/dev/null
    echo "✅ deleted: $1"
    ;;
  *)
    echo "════ module_036: auto_task_runner ════"
    echo "  action: $ACTION  category: system"
    echo "  hint: $0 add <name> [value] | $0 list | $0 delete <name>"
    ;;
esac
rc=$?; log "DONE rc=$rc"; exit $rc
