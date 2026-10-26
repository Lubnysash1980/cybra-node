#!/data/data/com.termux/files/usr/bin/bash
# module_033: ownership_scan (system)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_033.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
trap 'log "ERR line $LINENO"' ERR
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
log "START ownership_scan action=$ACTION"
KEY="cybra:system:data"

case "$ACTION" in
  add|create|register)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name> [value]"; exit 1; fi
    VAL="${2:-$(date +%s)}"
    redis-cli hset "$KEY" "$1" "$VAL" >/dev/null
    echo "OK: $1 = $VAL"
    ;;
  list|status|show)
    N=$(redis-cli hlen "$KEY" 2>/dev/null || echo 0)
    echo "==== system (module_033) ===="
    echo "  items: $N"
    if [ "$N" -gt 0 ]; then
      redis-cli hgetall "$KEY" | paste - - | head -20 | sed 's/^/  /'
    fi
    ;;
  delete|remove)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name>"; exit 1; fi
    redis-cli hdel "$KEY" "$1" >/dev/null
    echo "OK: deleted $1"
    ;;
  *)
    echo "==== module_033: ownership_scan ===="
    echo "  action: $ACTION  category: system"
    echo "  hint: $0 add <name> [value] | $0 list | $0 delete <name>"
    ;;
esac
rc=0; log "DONE rc=$rc"; exit $rc
