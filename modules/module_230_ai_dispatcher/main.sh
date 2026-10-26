#!/data/data/com.termux/files/usr/bin/bash
# module_230: ai_dispatcher (taxi)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
KEY="cybra:taxi:taxi:data"
case "$ACTION" in
  add|create|register)
    if [ $# -lt 1 ]; then echo "usage: $0 add <name>"; exit 1; fi
    redis-cli hset "$KEY" "$1" "${2:-$(date +%s)}" >/dev/null
    echo "OK: $1" ;;
  list|status|show)
    N=$(redis-cli hlen "$KEY" 2>/dev/null || echo 0)
    echo "==== taxi (module_230) ===="
    echo "  items: $N"
    if [ "$N" -gt 0 ]; then redis-cli hgetall "$KEY" | paste - - | head -20 | sed 's/^/  /'; fi ;;
  delete|remove)
    if [ $# -lt 1 ]; then exit 1; fi
    redis-cli hdel "$KEY" "$1" >/dev/null; echo "OK: deleted" ;;
  *) echo "==== module_230: ai_dispatcher ====" ;;
esac
exit 0
