#!/data/data/com.termux/files/usr/bin/bash
# module_271: live_share (share) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="live_share"
MODULE_CAT="share"

case "$ACTION" in
  start)
    RID="${1:-}"
    [ -z "$RID" ] && exit 1
    TOKEN=$(head -c 8 /dev/urandom | xxd -p)
    redis-cli hset "cybra:taxi:share:$TOKEN" "ride" "$RID" >/dev/null
    redis-cli hset "cybra:taxi:share:$TOKEN" "ts" "$(date -u +%FT%TZ)" >/dev/null
    redis-cli set "cybra:taxi:share:ride:$RID" "$TOKEN" >/dev/null
    echo "════ ${MODULE_LABEL} ════"
    echo "  share_token: $TOKEN"
    echo "  url:  https://cybra.app/t/$TOKEN"
    echo "  ride: $RID"
    ;;
  status)
    TOKEN="${1:-}"
    [ -z "$TOKEN" ] && exit 1
    echo "════ share $TOKEN ════"
    redis-cli hgetall "cybra:taxi:share:$TOKEN" 2>/dev/null | paste - -
    ;;
  stop)
    RID="${1:-}"
    [ -z "$RID" ] && exit 1
    TOKEN=$(redis-cli get "cybra:taxi:share:ride:$RID" 2>/dev/null)
    [ -n "$TOKEN" ] && redis-cli del "cybra:taxi:share:$TOKEN" >/dev/null
    redis-cli del "cybra:taxi:share:ride:$RID" >/dev/null
    echo "⏹ share stopped: $RID"
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 start <ride> | status <token> | stop <ride>"
    ;;
esac
