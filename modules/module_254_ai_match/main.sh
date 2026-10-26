#!/data/data/com.termux/files/usr/bin/bash
# module_254: ai_match (ai) — taxi_premium
# generated 2026-10-25T23:07:35Z
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="ai_match"
MODULE_CAT="ai"

case "$ACTION" in
  interests)
    WHO="${1:-}"; shift 2>/dev/null || true
    [ -z "$WHO" ] && { echo "usage: $0 interests <id> <tag1> [tag2] ..."; exit 1; }
    redis-cli del "cybra:taxi:interests:$WHO" >/dev/null
    for tag in "$@"; do
      redis-cli sadd "cybra:taxi:interests:$WHO" "$tag" >/dev/null
    done
    echo "✅ interests set for $WHO: $*"
    ;;
  match)
    RID="${1:-}"
    [ -z "$RID" ] && { echo "usage: $0 match <rider_id>"; exit 1; }
    echo "════ AI match: rider $RID ════"
    RI=$(redis-cli smembers "cybra:taxi:interests:$RID" 2>/dev/null)
    if [ -z "$RI" ]; then echo "  no interests set"; exit 0; fi
    echo "  rider interests: $(echo $RI | tr '\n' ' ')"
    BEST=""; BEST_SC=0
    for D in $(redis-cli keys "cybra:taxi:interests:*" 2>/dev/null | grep -v ":$RID$"); do
      DID=$(basename "$D" | sed 's/^cybra:taxi:interests://')
      DI=$(redis-cli smembers "$D" 2>/dev/null)
      [ -z "$DI" ] && continue
      SC=0
      for t in $RI; do echo "$DI" | grep -qw "$t" && SC=$((SC+1)); done
      if [ "$SC" -gt "$BEST_SC" ]; then BEST_SC=$SC; BEST=$DID; fi
    done
    if [ -n "$BEST" ]; then
      redis-cli hset cybra:taxi:match:data "$RID" "driver=$BEST,overlap=$BEST_SC" >/dev/null
      echo "  ✅ best: $BEST (shared: $BEST_SC)"
    else
      echo "  no matches"
    fi
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 interests <id> <tag1> <tag2> ... | match <rider_id>"
    echo "  NOTE: rating/comments NOT used (per spec)"
    ;;
esac
