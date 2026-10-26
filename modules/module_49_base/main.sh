#!/data/data/com.termux/files/usr/bin/bash
# module_049: executor_list (evolution)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_049.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
err() { log "ERR: $*"; echo "❌ $*" >&2; return 1; }
trap 'err "line $LINENO rc=$?"' ERR

CLI_HINT="$CYBRA/bin/cybra_evo_controller.py"
ACTION="${1:-status}"
shift $(( $# > 0 ? 1 : 0 ))
log "START module_049 action=$ACTION"

if [ -n "bin/cybra_evo_controller.py" ] && [ -e "$CLI_HINT" ]; then
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
    redis-cli hset "cybra:evolution:data" "$1" "$VAL" >/dev/null
    redis-cli set "cybra:evolution:$1" "$VAL" >/dev/null
    echo "✅ evolution: $1 = $VAL" ;;
  list|status|show)
    n=$(redis-cli hlen "cybra:evolution:data" 2>/dev/null || echo 0)
    echo "════ evolution (module_049) ════"
    echo "  items: $n"
    if [ "$n" -gt 0 ]; then
      redis-cli hgetall "cybra:evolution:data" | paste - - | head -20 | sed 's/^/  /'
    fi ;;
  delete|remove)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name>"; exit 1; fi
    redis-cli hdel "cybra:evolution:data" "$1" >/dev/null
    redis-cli del "cybra:evolution:$1" >/dev/null
    echo "✅ deleted: $1" ;;
  *)
    echo "════ module_049: executor_list ════"
    echo "  action: $ACTION  category: evolution"
    echo "  hint: $0 add <name> [value] | $0 list | $0 delete <name>" ;;
esac
rc=$?; log "DONE action=$ACTION rc=$rc"; exit $rc
