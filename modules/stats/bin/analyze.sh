#!/data/data/com.termux/files/usr/bin/bash
# analyze.sh — detect patterns, propose root cause to parliament (debounced)
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
STATE="$MOD/state"
RULES="$MOD/rules.json"
CUR="$STATE/current.json"
[ -f "$CUR" ] || { echo '{"anomalies":[]}'; exit 0; }

T=$(jq '.thresholds' "$RULES")
DEBOUNCE=$(jq -r '.debounce_sec // 3600' "$RULES")
PROPOSE=$(jq -r '.propose_to_parliament // true' "$RULES")

th() { jq -r --arg k "$1" '.thresholds[$k] // 999' "$RULES"; }

ANOM='[]'
push_anom() {
    ANOM=$(echo "$ANOM" | jq --arg t "$1" --arg m "$2" --argjson v "$3" \
        '. + [{type:$t, msg:$m, value:$v}]')
}

# 1) same_repair: one component repaired too many times
SAME_TH=$(th same_repair)
echo "$(jq -r '.autodopomoga.by_component // {}' "$CUR")" | jq -r 'to_entries[] | "\(.key) \(.value)"' | while read -r comp n; do
    [ -z "$comp" ] && continue
    if [ "$n" -ge "$SAME_TH" ]; then
        echo "SAME_REPAIR $comp $n" >> "$STATE/.anomalies.tmp"
    fi
done

# 2) god_kill spike
GOD_TH=$(th god_kill)
GOD_N=$(jq -r '.autowatch.god_dead // 0' "$CUR")
[ "$GOD_N" -ge "$GOD_TH" ] && echo "GOD_KILL god $GOD_N" >> "$STATE/.anomalies.tmp"

# 3) repair cycle spike
RC_TH=$(th repair_cycle)
RC_N=$(jq -r '.autodopomoga.repair_cycles // 0' "$CUR")
[ "$RC_N" -ge "$RC_TH" ] && echo "REPAIR_SPIKE all $RC_N" >> "$STATE/.anomalies.tmp"

# 4) veto spike
VS_TH=$(th veto_spike)
VS_N=$(jq -r '.parliament.vetoed // 0' "$CUR")
[ "$VS_N" -ge "$VS_TH" ] && echo "VETO_SPIKE parliament $VS_N" >> "$STATE/.anomalies.tmp"

# 5) bg_dump fail streak
BF_TH=$(th bg_dump_fail)
BF_N=$(( $(jq -r '.bg_dump.comp_fail // 0' "$CUR") + $(jq -r '.bg_dump.global_fail // 0' "$CUR") ))
[ "$BF_N" -ge "$BF_TH" ] && echo "DUMP_FAIL dump $BF_N" >> "$STATE/.anomalies.tmp"

# read collected anomalies
if [ -f "$STATE/.anomalies.tmp" ]; then
    while read -r type comp n; do
        [ -z "$type" ] && continue
        ANOM=$(echo "$ANOM" | jq --arg t "$type" --arg c "$comp" --argjson v "$n" \
            '. + [{type:$t, component:$c, value:$v}]')
    done < "$STATE/.anomalies.tmp"
    rm -f "$STATE/.anomalies.tmp"
fi

# propose to parliament (debounced per type)
if [ "$PROPOSE" = "true" ] && [ "$(echo "$ANOM" | jq 'length')" -gt 0 ]; then
    PARL="$CYBRA/modules/parliament/bin/parliament.sh"
    DEBOUNCE_FILE="$STATE/.last-propose.ts"
    NOW=$(date +%s)
    LAST=$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo 0)
    AGE=$((NOW - LAST))
    if [ "$AGE" -gt "$DEBOUNCE" ] && [ -x "$PARL" ]; then
        # aggregate anomalies into one proposal
        MSG=$(echo "$ANOM" | jq -r '.[] | "\(.type) \(.component // "all") x\(.value)"' | tr '\n' ';')
        GOAL="stats: recurring problems detected: $MSG"
        EXEC="~/CYBRA/modules/stats/bin/report.sh full"
        "$PARL" propose --goal "$GOAL" --exec "$EXEC" --preview >> "$CYBRA/logs/stats.log" 2>&1
        echo "$NOW" > "$DEBOUNCE_FILE"
        echo "[$(date '+%F %T')] proposed to parliament: $MSG" >> "$CYBRA/logs/stats.log"
    fi
fi

# output + append history
OUT=$(jq -n --argjson a "$ANOM" --argjson ts "$(date +%s)" \
    '{ts:$ts, anomalies:$a, count:($a|length)}')
echo "$OUT" > "$STATE/anomalies.json"
echo "$OUT" >> "$STATE/history.jsonl"

# trim history
KEEP=$(jq -r '.history_keep_lines // 1000' "$RULES")
if [ -f "$STATE/history.jsonl" ]; then
    LINES=$(wc -l < "$STATE/history.jsonl")
    if [ "$LINES" -gt "$KEEP" ]; then
        tail -n "$KEEP" "$STATE/history.jsonl" > "$STATE/history.jsonl.t" && mv "$STATE/history.jsonl.t" "$STATE/history.jsonl"
    fi
fi

echo "$OUT"
