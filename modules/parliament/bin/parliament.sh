#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
STATE="$MOD/state"; mkdir -p "$STATE/proposals" "$STATE/decisions"
LOG="$CYBRA/logs/parliament.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

cmd="${1:-help}"; shift || true

case "$cmd" in
  propose)
    GOAL=""; EXEC=""; PREVIEW="no"
    while [ $# -gt 0 ]; do
      case "$1" in
        --goal) GOAL="$2"; shift 2 ;;
        --exec) EXEC="$2"; shift 2 ;;
        --preview) PREVIEW="yes"; shift ;;
        *) shift ;;
      esac
    done
    [ -z "$GOAL" ] && { echo "usage: propose --goal '...' --exec '...' [--preview]"; exit 1; }
    ID="p_$(date +%Y%m%d_%H%M%S)_${RANDOM}${RANDOM}"
    P="$STATE/proposals/$ID.json"
    jq -n --arg id "$ID" --arg goal "$GOAL" --arg exec "$EXEC" --argjson ts "$(date +%s)" \
      '{id:$id,ts:$ts,goal:$goal,exec:$exec,status:"pending",votes:{},decision:null}' > "$P"
    echo "✓ proposal: $ID"
    echo "  goal: $GOAL"
    echo "  exec: $EXEC"
    if [ "$PREVIEW" = "yes" ]; then
      echo ""
      echo "── safety preview ──"
      cat "$P" | "$MOD/bin/judges/safety.sh" | jq .
    fi
    echo "  decide: $0 decide $ID"
    ;;

  decide)
    ID="${1:-}"; [ -z "$ID" ] && { echo "usage: decide <id>"; exit 1; }
    P="$STATE/proposals/$ID.json"; [ -f "$P" ] || { echo "no such proposal"; exit 1; }
    log "── debate $ID ──"
    PROP=$(cat "$P"); TW=0; AS=0; VJ="{}"; VETOED_BY=""

    for D in "$MOD"/departments/*.json; do
      [ -f "$D" ] || continue
      DID=$(jq -r '.id' "$D"); DW=$(jq -r '.weight' "$D")
      CV=$(jq -r '.can_veto // false' "$D"); J=$(jq -r '.judge' "$D")
      [ -x "$MOD/$J" ] || { log "  $DID: judge missing"; continue; }
      V=$(echo "$PROP" | "$MOD/$J" 2>/dev/null)
      if ! echo "${V:-null}" | jq -e . >/dev/null 2>&1; then
        log "  $DID: judge error → abstain"; continue
      fi
      SC=$(echo "$V" | jq -r '.score // 50')
      VD=$(echo "$V" | jq -r '.verdict // "abstain"')
      RS=$(echo "$V" | jq -r '.reason // ""')
      log "  $DID (w=$DW veto=$CV): $VD score=$SC — $RS"
      VJ=$(echo "$VJ" | jq --arg k "$DID" --argjson v "$V" '. + {($k):$v}')
      [ "$VD" = "abstain" ] && continue
      TW=$((TW + DW)); AS=$((AS + SC * DW))
      if [ "$VD" = "reject" ] && [ "$CV" = "true" ]; then
        VETOED_BY="$DID"
      fi
    done

    if [ -n "$VETOED_BY" ]; then
      W=0; STATUS=vetoed
      log "  → VETOED by $VETOED_BY"
    elif [ "$TW" -eq 0 ]; then
      log "  no valid votes"; exit 1
    else
      W=$(awk -v a="$AS" -v t="$TW" 'BEGIN{ printf "%.1f", a/t }')
      if awk -v w="$W" 'BEGIN{ exit !(w>=50) }'; then
        STATUS=approved
      else
        STATUS=rejected
      fi
      log "  weighted approve: $W (threshold 50) → $STATUS"
    fi

    if [ "$STATUS" = "approved" ]; then
      jq --argjson v "$VJ" --argjson w "$W" '. + {status:"approved",votes:$v,weighted:$w}' "$P" > "$P.t" && mv "$P.t" "$P"
      log "  → APPROVED. baseline + execute."
      "$MOD/bin/baseline.sh" >/dev/null
      EXEC=$(jq -r '.exec' "$P")
      log "  exec: $EXEC"
      bash -c "$EXEC" >> "$LOG" 2>&1
      RC=$?
      log "  exec done rc=$RC. waiting 5s..."
      sleep 5
      if "$MOD/bin/sanity.sh" >/dev/null 2>&1; then
        log "  ✅ sanity OK → new baseline"
        "$MOD/bin/baseline.sh" >/dev/null
        jq --argjson d '{"verdict":"ok"}' '.decision=$d' "$P" > "$P.t" && mv "$P.t" "$P"
      else
        log "  ⚠ sanity FAIL → ROLLBACK"
        jq --argjson d '{"verdict":"rollback"}' '.decision=$d' "$P" > "$P.t" && mv "$P.t" "$P"
        "$MOD/bin/rollback.sh"
      fi
    else
      EXTRA='{}'
      [ -n "$VETOED_BY" ] && EXTRA=$(jq -n --arg v "$VETOED_BY" '{vetoed_by:$v}')
      jq --argjson v "$VJ" --argjson w "$W" --arg s "$STATUS" --argjson e "$EXTRA" \
        '. + {status:$s,votes:$v,weighted:$w} + $e' "$P" > "$P.t" && mv "$P.t" "$P"
      MSG="  → $STATUS"
      [ -n "$VETOED_BY" ] && MSG="$MSG (VETO by $VETOED_BY)"
      log "$MSG"
    fi
    jq '{status,weighted,vetoed_by,decision}' "$P"
    ;;

  status)
    echo "── proposals ──"
    for P in "$STATE"/proposals/*.json; do
      [ -f "$P" ] || continue
      jq -r '"\(.id)  \(.status)  w=\(.weighted // "-")  \(.goal)"' "$P"
    done
    echo ""
    echo "── sanity ──"
    "$MOD/bin/sanity.sh"
    echo ""
    echo "── last measure ──"
    [ -f "$STATE/last-measure.json" ] && jq . "$STATE/last-measure.json"
    ;;

  baseline) "$MOD/bin/baseline.sh" ;;
  measure)  "$MOD/bin/measure.sh" ;;
  sanity)   "$MOD/bin/sanity.sh" ;;
  log)      tail -n "${1:-30}" "$LOG" ;;
  *) echo "usage: parliament.sh {propose|decide|status|baseline|measure|sanity|log}" ;;
esac
