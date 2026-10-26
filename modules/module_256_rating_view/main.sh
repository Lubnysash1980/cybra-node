#!/data/data/com.termux/files/usr/bin/bash
# module_256: rating_view (rating)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
KEY="cybra:taxi:rating:data"
case "$ACTION" in
  add|create) if [ $# -lt 1 ]; then exit 1; fi
    redis-cli hset "$KEY" "$1" "${2:-$(date +%s)}" >/dev/null; echo "OK: $1" ;;
  list|status|show) N=$(redis-cli hlen "$KEY" 2>/dev/null || echo 0)
    echo "==== rating (module_256) ===="; echo "  items: $N"
    [ "$N" -gt 0 ] && redis-cli hgetall "$KEY" | paste - - | head -20 | sed 's/^/  /' ;;
  delete) redis-cli hdel "$KEY" "$1" >/dev/null; echo "OK: deleted" ;;
  *) echo "==== module_256: rating_view ====" ;;
esac
exit 0
