#!/data/data/com.termux/files/usr/bin/bash
# module_257: rating_comments (rating) — taxi_premium
# generated 2026-10-25T23:07:35Z
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="rating_comments"
MODULE_CAT="rating"

case "$ACTION" in
  add)
    WHO="${1:-}"; SC="${2:-}"; shift 2>/dev/null || true
    COMMENT="$*"
    [ -z "$WHO" ] || [ -z "$SC" ] && { echo "usage: $0 add <who> <1-5> [comment]"; exit 1; }
    RID="R-$(date +%s)"
    redis-cli hset cybra:taxi:rating:data "$RID" "$WHO|score=$SC|$COMMENT|$(date -u +%FT%TZ)" >/dev/null
    echo "⭐ saved ($RID) — does NOT affect dispatch/AI"
    ;;
  view|list|*)
    WHO="${1:-}"
    echo "════ ${MODULE_LABEL} ════"
    redis-cli hgetall cybra:taxi:rating:data 2>/dev/null | paste - - | while read k v; do
      if [ -z "$WHO" ] || echo "$v" | grep -q "^$WHO|"; then
        echo "  $k: $v"
      fi
    done
    echo "  NOTE: rating only for review — does NOT affect driver work"
    ;;
esac
