#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
CONTRACTS="$MOD/contracts.json"
STATE="$MOD/state"; mkdir -p "$STATE"
PIDFILE="$CYBRA/.cache/autodopomoga.pid"
LOG="$CYBRA/logs/autodopomoga.log"
ATTEMPTS="$STATE/attempts.json"
HISTORY="$STATE/history.log"
mkdir -p "$CYBRA/.cache" "$CYBRA/logs"
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

if [ -f "$PIDFILE" ]; then
    OLD=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null && { log "already running pid=$OLD"; exit 0; }
    rm -f "$PIDFILE"
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT

POLL="${POLL:-30}"
BACKOFF="${BACKOFF:-10}"
THRESHOLD="${THRESHOLD:-3.0}"
GLOBAL_MAX_CYCLES="${GLOBAL_MAX_CYCLES:-10}"
GLOBAL_COOLDOWN="${GLOBAL_COOLDOWN:-1800}"

[ -f "$ATTEMPTS" ] || echo '{}' > "$ATTEMPTS"
touch "$HISTORY"

log "═══ AUTODOPOMOGA START ═══ pid=$$ poll=${POLL}s threshold=${THRESHOLD}%"

get_count(){ jq -r --arg c "$1" '.[$c].count // 0' "$ATTEMPTS" 2>/dev/null; }
get_last_ts(){ jq -r --arg c "$1" '.[$c].last_ts // 0' "$ATTEMPTS" 2>/dev/null; }
inc_count(){
    local c="$1" n
    n=$(jq -r --arg c "$c" '.[$c].count // 0' "$ATTEMPTS" 2>/dev/null)
    jq --arg c "$c" --argjson n $((n+1)) --argjson ts "$(date +%s)" \
        '.[$c] = {count:$n, last_ts:$ts}' "$ATTEMPTS" > "$ATTEMPTS.t" && mv "$ATTEMPTS.t" "$ATTEMPTS"
}
reset_comp(){ jq --arg c "$1" 'del(.[$c])' "$ATTEMPTS" > "$ATTEMPTS.t" && mv "$ATTEMPTS.t" "$ATTEMPTS"; }
reset_all(){ echo '{}' > "$ATTEMPTS"; }

CYCLES=0
LAST_CYCLE_RESET=$(date +%s)

while true; do
    NOW=$(date +%s)
    if [ $((NOW - LAST_CYCLE_RESET)) -ge "$GLOBAL_COOLDOWN" ]; then
        CYCLES=0; LAST_CYCLE_RESET=$NOW
    fi

    V=$("$MOD/bin/verify.sh" 2>/dev/null)
    DEV=$(echo "$V" | jq -r '.deviation // 0' 2>/dev/null || echo 0)
    UNHEALTHY=$(echo "$V" | jq -r '.unhealthy[]?' 2>/dev/null)

    if [ -z "$UNHEALTHY" ]; then
        if [ "$(cat "$ATTEMPTS" 2>/dev/null)" != "{}" ] && [ -s "$ATTEMPTS" ]; then
            log "✅ 100% healthy — reset attempts"
            reset_all
        fi
        CYCLES=0
        sleep "$POLL"
        continue
    fi

    log "⚠ deviation=${DEV}% unhealthy=[$(echo $UNHEALTHY | tr '\n' ' ')]"

    if [ "$CYCLES" -ge "$GLOBAL_MAX_CYCLES" ]; then
        log "⛔ global cycle cap ($GLOBAL_MAX_CYCLES) — cooldown ${GLOBAL_COOLDOWN}s"
        sleep "$GLOBAL_COOLDOWN"
        CYCLES=0; LAST_CYCLE_RESET=$(date +%s)
        continue
    fi

    CYCLES=$((CYCLES + 1))
    log "── repair cycle $CYCLES/$GLOBAL_MAX_CYCLES ──"

    ANY_REPAIRED=0
    for comp in $UNHEALTHY; do
        MAX=$(jq -r --arg c "$comp" '.[$c].max_attempts // 3' "$CONTRACTS")
        COOL=$(jq -r --arg c "$comp" '.[$c].cooldown_sec // 600' "$CONTRACTS")
        CNT=$(get_count "$comp"); LTS=$(get_last_ts "$comp"); AGE=$((NOW - LTS))

        if [ "$CNT" -ge "$MAX" ]; then
            if [ "$AGE" -lt "$COOL" ]; then
                log "  skip $comp: attempts=$CNT/$MAX, age=${AGE}s < cooldown=${COOL}s"
                continue
            fi
            log "  reset $comp: cooldown expired (age=${AGE}s)"
            reset_comp "$comp"; CNT=0
        fi

        NEXT=$((CNT + 1))
        log "  repair $comp (attempt $NEXT/$MAX)"
        "$MOD/bin/repair.sh" "$comp" "$NEXT" >> "$HISTORY" 2>&1
        inc_count "$comp"
        ANY_REPAIRED=1
    done

    if [ "$ANY_REPAIRED" -eq 0 ]; then
        log "⛔ no repairs possible (all cooldown) — escalating to parliament"
        PARL="$CYBRA/modules/parliament/bin/parliament.sh"
        if [ -x "$PARL" ] && ! "$PARL" status 2>/dev/null | grep -q pending; then
            "$PARL" propose \
                --goal "autodopomoga exhausted: [$(echo $UNHEALTHY | tr '\n' ' ')] deviation=${DEV}%" \
                --exec "$CYBRA/modules/parliament/bin/rollback.sh" \
                --preview >> "$LOG" 2>&1
        fi
        sleep "$GLOBAL_COOLDOWN"
        CYCLES=0; LAST_CYCLE_RESET=$(date +%s)
        continue
    fi

    sleep "$BACKOFF"
    V2=$("$MOD/bin/verify.sh" 2>/dev/null)
    DEV2=$(echo "$V2" | jq -r '.deviation // 0' 2>/dev/null || echo 0)
    log "  after repair: deviation=${DEV2}%"

    if awk -v d="$DEV2" -v t="$THRESHOLD" 'BEGIN{ exit !(d < t) }'; then
        log "✅ ${DEV2}% < ${THRESHOLD}% — back to 100%"
        reset_all
        CYCLES=0; LAST_CYCLE_RESET=$(date +%s)
        sleep "$POLL"
    else
        sleep 2
    fi
done
