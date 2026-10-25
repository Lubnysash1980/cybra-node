#!/data/data/com.termux/files/usr/bin/bash
# module_087: snapshot_git_restore (snapshot)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_087.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
err() { log "ERR: $*"; echo "❌ $*" >&2; return 1; }
trap 'err "line $LINENO rc=$?"' ERR

CLI_HINT="$CYBRA/"
ACTION="${1:-git}"
shift $(( $# > 0 ? 1 : 0 ))
log "START module_087 action=$ACTION"

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
    redis-cli hset "cybra:snapshot:data" "$1" "$VAL" >/dev/null
    redis-cli set "cybra:snapshot:$1" "$VAL" >/dev/null
    echo "✅ snapshot: $1 = $VAL" ;;
  list|status|show)
    n=$(redis-cli hlen "cybra:snapshot:data" 2>/dev/null || echo 0)
    echo "════ snapshot (module_087) ════"
    echo "  items: $n"
    if [ "$n" -gt 0 ]; then
      redis-cli hgetall "cybra:snapshot:data" | paste - - | head -20 | sed 's/^/  /'
    fi ;;
  delete|remove)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name>"; exit 1; fi
    redis-cli hdel "cybra:snapshot:data" "$1" >/dev/null
    redis-cli del "cybra:snapshot:$1" >/dev/null
    echo "✅ deleted: $1" ;;
  *)
    echo "════ module_087: snapshot_git_restore ════"
    echo "  action: $ACTION  category: snapshot"
    echo "  hint: $0 add <name> [value] | $0 list | $0 delete <name>" ;;
esac
rc=$?; log "DONE action=$ACTION rc=$rc"; exit $rc
