#!/data/data/com.termux/files/usr/bin/bash
# module_145: ipfs (ipfs)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_145.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
err() { log "ERR: $*"; echo "❌ $*" >&2; return 1; }
trap 'err "line $LINENO rc=$?"' ERR

CLI_HINT="$CYBRA/"
ACTION="${1:-pin}"
shift $(( $# > 0 ? 1 : 0 ))
log "START module_145 action=$ACTION"

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
    redis-cli hset "cybra:ipfs:data" "$1" "$VAL" >/dev/null
    redis-cli set "cybra:ipfs:$1" "$VAL" >/dev/null
    echo "✅ ipfs: $1 = $VAL" ;;
  list|status|show)
    n=$(redis-cli hlen "cybra:ipfs:data" 2>/dev/null || echo 0)
    echo "════ ipfs (module_145) ════"
    echo "  items: $n"
    if [ "$n" -gt 0 ]; then
      redis-cli hgetall "cybra:ipfs:data" | paste - - | head -20 | sed 's/^/  /'
    fi ;;
  delete|remove)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name>"; exit 1; fi
    redis-cli hdel "cybra:ipfs:data" "$1" >/dev/null
    redis-cli del "cybra:ipfs:$1" >/dev/null
    echo "✅ deleted: $1" ;;
  *)
    echo "════ module_145: ipfs ════"
    echo "  action: $ACTION  category: ipfs"
    echo "  hint: $0 add <name> [value] | $0 list | $0 delete <name>" ;;
esac
rc=$?; log "DONE action=$ACTION rc=$rc"; exit $rc
