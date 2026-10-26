#!/data/data/com.termux/files/usr/bin/bash
# module_056: webhook_list (webhook)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_056.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
err() { log "ERR: $*"; echo "❌ $*" >&2; return 1; }
trap 'err "line $LINENO rc=$?"' ERR

CLI_HINT="$CYBRA/"
ACTION="${1:-list}"
shift $(( $# > 0 ? 1 : 0 ))
log "START module_056 action=$ACTION"

if [ -n "" ] && [ -e "$CLI_HINT" ]; then
  case "$CLI_HINT" in
    *.py) python3 "$CLI_HINT" "$ACTION" "$@" ;;
    *)    bash "$CLI_HINT" "$ACTION" "$@" ;;
  esac
  rc=$?; log "DONE cli rc=$rc"; exit $rc
fi

case "$ACTION" in
  add|create|register)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name> [value]"; exit 1; fi
    VAL="${2:-$(date +%s)}"
    redis-cli hset "cybra:webhook:data" "$1" "$VAL" >/dev/null
    redis-cli set "cybra:webhook:$1" "$VAL" >/dev/null
    echo "✅ webhook: $1 = $VAL" ;;
  list|status|show)
    n=$(redis-cli hlen "cybra:webhook:data" 2>/dev/null || echo 0)
    echo "════ webhook (module_056) ════"
    echo "  items: $n"
    if [ "$n" -gt 0 ]; then
      redis-cli hgetall "cybra:webhook:data" | paste - - | head -20 | sed 's/^/  /'
    fi ;;
  delete|remove)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name>"; exit 1; fi
    redis-cli hdel "cybra:webhook:data" "$1" >/dev/null
    redis-cli del "cybra:webhook:$1" >/dev/null
    echo "✅ deleted: $1" ;;
  *)
    echo "════ module_056: webhook_list ════"
    echo "  action: $ACTION  category: webhook"
    echo "  hint: $0 add <name> [value] | $0 list | $0 delete <name>" ;;
esac
rc=$?; log "DONE action=$ACTION rc=$rc"; exit $rc
