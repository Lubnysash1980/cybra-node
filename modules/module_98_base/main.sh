#!/data/data/com.termux/files/usr/bin/bash
# module_098: parawatch (parawatch)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_098.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
err() { log "ERR: $*"; echo "❌ $*" >&2; return 1; }
trap 'err "line $LINENO rc=$?"' ERR

CLI_HINT="$CYBRA/bin/cybra_parawatch"
ACTION="${1:-status}"
shift $(( $# > 0 ? 1 : 0 ))
log "START module_098 action=$ACTION"

if [ -n "bin/cybra_parawatch" ] && [ -e "$CLI_HINT" ]; then
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
    redis-cli hset "cybra:parawatch:data" "$1" "$VAL" >/dev/null
    redis-cli set "cybra:parawatch:$1" "$VAL" >/dev/null
    echo "✅ parawatch: $1 = $VAL" ;;
  list|status|show)
    n=$(redis-cli hlen "cybra:parawatch:data" 2>/dev/null || echo 0)
    echo "════ parawatch (module_098) ════"
    echo "  items: $n"
    if [ "$n" -gt 0 ]; then
      redis-cli hgetall "cybra:parawatch:data" | paste - - | head -20 | sed 's/^/  /'
    fi ;;
  delete|remove)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name>"; exit 1; fi
    redis-cli hdel "cybra:parawatch:data" "$1" >/dev/null
    redis-cli del "cybra:parawatch:$1" >/dev/null
    echo "✅ deleted: $1" ;;
  *)
    echo "════ module_098: parawatch ════"
    echo "  action: $ACTION  category: parawatch"
    echo "  hint: $0 add <name> [value] | $0 list | $0 delete <name>" ;;
esac
rc=$?; log "DONE action=$ACTION rc=$rc"; exit $rc
