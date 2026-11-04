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
    GOAL=""; EXEC=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --goal) GOAL="$2"; shift 2 ;;
        --exec) EXEC="$2"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -z "$GOAL" ] && { echo "usage: propose --goal '...' --exec '...'"; exit 1; }
    ID="p_$(date +%Y%m%d_%H%M%S)_${RANDOM}${RANDOM}"
    P="$STATE/proposals/$ID.json"
    jq -n --arg id "$ID" --arg goal "$GOAL" --arg exec "$EXEC" --argjson ts "$(date +%s)" \
      '{id:$id,ts:$ts,goal:$goal,exec:$exec,status:"pending",votes:{},decision:null}' > "$P"
    echo "✓ proposal: $ID"
    echo "  goal: $GOAL"
    echo "  exec: $EXEC"
    echo "  decide: $0 decide $ID"
    ;;

  decide)
    ID="${1:-}"; [ -z "$ID" ] && { echo "usage: decide <id>"; exit 1; }
    P="$STATE/proposals/$ID.json"; [ -f "$P" ] || { echo "no such proposal"; exit 1; }
    log "── debate $ID ──"
    PROP=$(cat "$P"); TW=0; AS=0; VJ="{}"

    for D in "$MOD"/departments/*.json; do
      [ -f "$D" ] || continue
      DID=$(jq -r '.id' "$D"); DW=$(jq -r '.weight' "$D"); J=$(jq -r '.judge' "$D")
      [ -x "$MOD/$J" ] || { log "  $DID: judge missing"; continue; }
      V=$(echo "$PROP" | "$MOD/$J" 2>/dev/null)
      SC=$(echo "${V:-null}" | jq -r '.score // 0' 2>/dev/null || echo 0)
      VD=$(echo "${V:-null}" | jq -r '.verdict // "abstain"' 2>/dev/null || echo "abstain")
      RS=$(echo "${V:-null}" | jq -r '.reason // ""' 2>/dev/null || echo "")
      log "  $DID (w=$DW): $VD score=$SC — $RS"
      VJ=$(echo "$VJ" | jq --arg k "$DID" --argjson v "${V:-{\}}" '. + {($k):$v}')
      TW=$((TW + DW))
      [ "$VD" = "approve" ] && AS=$((AS + SC * DW))
    done

    [ "$TW" -eq 0 ] && { log "no departments"; exit 1; }
    W=$(awk -v a="$AS" -v t="$TW" 'BEGIN{ printf "%.1f", a/t }')
    PASS=$(awk -v w="$W" 'BEGIN{ print (w>=50)?"yes":"no" }')
    log "  weighted approve: $W (threshold 50) → $PASS"

    if [ "$PASS" = "yes" ]; then
      jq --argjson v "$VJ" --argjson w "$W" '. + {status:"approved",votes:$v,weighted:$w}' "$P" > "$P.t" && mv "$P.t" "$P"
      log "  → APPROVED. baseline + execute."
      "$MOD/bin/baseline.sh" >/dev/null
      EXEC=$(jq -r '.exec' "$P")
      log "  exec: $EXEC"
      bash -c "$EXEC" >> "$LOG" 2>&1
      log "  exec done. waiting 5s..."
      sleep 5
      if "$MOD/bin/measure.sh" >/dev/null 2>&1; then
        log "  ✅ no deviation"
        jq --argjson d '{"verdict":"ok"}' '.decision=$d' "$P" > "$P.t" && mv "$P.t" "$P"
      else
        log "  ⚠ deviation → ROLLBACK"
        jq --argjson d '{"verdict":"rollback"}' '.decision=$d' "$P" > "$P.t" && mv "$P.t" "$P"
        "$MOD/bin/rollback.sh"
      fi
    else
      jq --argjson v "$VJ" --argjson w "$W" '. + {status:"rejected",votes:$v,weighted:$w}' "$P" > "$P.t" && mv "$P.t" "$P"
      log "  → REJECTED"
    fi
    jq '.status, .weighted, .decision' "$P"
    ;;

  status)
    echo "── proposals ──"
    for P in "$STATE"/proposals/*.json; do
      [ -f "$P" ] || continue
      jq -r '"\(.id)  \(.status)  w=\(.weighted // "-")  \(.goal)"' "$P"
    done
    echo ""
    echo "── last measure ──"
    [ -f "$STATE/last-measure.json" ] && jq . "$STATE/last-measure.json"
    ;;

  baseline) "$MOD/bin/baseline.sh" ;;
  measure)  "$MOD/bin/measure.sh" ;;
  log)      tail -n "${1:-30}" "$LOG" ;;
  *) echo "usage: parliament.sh {propose|decide|status|baseline|measure|log}" ;;
esac
