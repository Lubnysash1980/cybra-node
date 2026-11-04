#!/data/data/com.termux/files/usr/bin/bash
# collect.sh — parse logs, emit JSON stats for window (default 1h)
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
STATE="$MOD/state"; mkdir -p "$STATE"
RULES="$MOD/rules.json"

WIN="${1:-}"
[ -z "$WIN" ] && WIN=$(jq -r '.window_sec // 3600' "$RULES")
CUT=$(date -d "@$(( $(date +%s) - WIN ))" '+%Y-%m-%d %H:%M:%S')

# helper: count lines in log matching pattern after CUT timestamp
cnt() {
    local log="$1" pat="$2"
    [ -f "$log" ] || { echo 0; return; }
    awk -v cut="$CUT" -v pat="$pat" '
        match($0, /\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]/) {
            ts = substr($0, RSTART+1, 19)
            if (ts >= cut && $0 ~ pat) n++
        }
        END { print n+0 }
    ' "$log"
}

# ── autowatch ──
AW=$(cnt "$CYBRA/logs/autowatch.log" "kill extras")
AG=$(cnt "$CYBRA/logs/autowatch.log" "god DEAD")
BD=$(cnt "$CYBRA/logs/autowatch.log" "bg_dump DEAD")
AU=$(cnt "$CYBRA/logs/autowatch.log" "autogit missing")

# ── bg_dump ──
COK=$(cnt "$CYBRA/logs/bg_dump.log" "comp dump ok")
CFA=$(cnt "$CYBRA/logs/bg_dump.log" "comp dump fail")
GOK=$(cnt "$CYBRA/logs/bg_dump.log" "global dump ok")
GFA=$(cnt "$CYBRA/logs/bg_dump.log" "global dump fail")
GRS=$(cnt "$CYBRA/logs/bg_dump.log" "resurrect done")

# ── autodopomoga ──
RC=$(cnt "$CYBRA/logs/autodopomoga.log" "repair cycle")
RD=$(cnt "$CYBRA/logs/autodopomoga.log" "after repair")

# ── autogit ──
AP=$(cnt "$CYBRA/logs/autogit.log" "push ok")
AF=$(cnt "$CYBRA/logs/autogit.log" "push fail")

# ── parliament-auto ──
PR=$(cnt "$CYBRA/logs/parliament-auto.log" "ROLLBACK detected")
PP=$(cnt "$CYBRA/logs/parliament-auto.log" "PROPOSING")

# ── parliament: proposals by status ──
PA=0; PV=0; PJ=0; PN=0
if ls "$CYBRA/modules/parliament/state/proposals/"*.json >/dev/null 2>&1; then
    PA=$(jq -s 'map(select(.status=="approved"))|length' "$CYBRA/modules/parliament/state/proposals/"*.json 2>/dev/null || echo 0)
    PV=$(jq -s 'map(select(.status=="vetoed"))|length'   "$CYBRA/modules/parliament/state/proposals/"*.json 2>/dev/null || echo 0)
    PJ=$(jq -s 'map(select(.status=="rejected"))|length' "$CYBRA/modules/parliament/state/proposals/"*.json 2>/dev/null || echo 0)
    PN=$(jq -s 'map(select(.status=="pending"))|length'  "$CYBRA/modules/parliament/state/proposals/"*.json 2>/dev/null || echo 0)
fi

# ── repair by component (from autodopomoga.log — has timestamps) ──
DLOG="$CYBRA/logs/autodopomoga.log"
REPAIRS='{}'
if [ -f "$DLOG" ]; then
    REPAIRS=$(awk -v cut="$CUT" '
        match($0, /\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]/) {
            ts = substr($0, RSTART+1, 19)
            if (ts >= cut && match($0, /repair [a-z_]+ \(attempt/)) {
                comp = substr($0, RSTART+7, RLENGTH-7)
                print comp
            }
        }
    ' "$DLOG" | sort | uniq -c | awk '{print $2" "$1}' | jq -Rn '[inputs | split(" ") | {(.[0]): (.[1]|tonumber)}] | add // {}')
fi

# ── pm2 ──
GOD=$(pgrep -f 'PM2.*God Daemon' 2>/dev/null | wc -l)
PM2ON=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length' 2>/dev/null || echo 0)
PM2ER=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="errored")]|length' 2>/dev/null || echo 0)

# ── daemons ──
DAEMONS='{}'
for n in autowatch bg_dump autodopomoga parliament-auto stats; do
    P=$(cat "$CYBRA/.cache/$n.pid" 2>/dev/null)
    if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then
        DAEMONS=$(echo "$DAEMONS" | jq --arg k "$n" '. + {($k): "running"}')
    else
        DAEMONS=$(echo "$DAEMONS" | jq --arg k "$n" '. + {($k): "stopped"}')
    fi
done

jq -n \
  --argjson ts "$(date +%s)" --argjson win "$WIN" --arg cut "$CUT" \
  --argjson aw "$AW" --argjson ag "$AG" --argjson bd "$BD" --argjson au "$AU" \
  --argjson cok "$COK" --argjson cfa "$CFA" --argjson gok "$GOK" \
  --argjson gfa "$GFA" --argjson grs "$GRS" \
  --argjson rc "$RC" --argjson rd "$RD" --argjson repairs "$REPAIRS" \
  --argjson ap "$AP" --argjson af "$AF" \
  --argjson pr "$PR" --argjson pp "$PP" \
  --argjson pa "$PA" --argjson pv "$PV" --argjson pj "$PJ" --argjson pn "$PN" \
  --argjson god "$GOD" --argjson pm2on "$PM2ON" --argjson pm2er "$PM2ER" \
  --argjson daemons "$DAEMONS" \
  '{
    ts: $ts, window_sec: $win, window_cut: $cut,
    autowatch: {kill_extras: $aw, god_dead: $ag, bg_dump_dead: $bd, autogit_missing: $au},
    bg_dump: {comp_ok: $cok, comp_fail: $cfa, global_ok: $gok, global_fail: $gfa, resurrects: $grs},
    autodopomoga: {repair_cycles: $rc, after_repairs: $rd, by_component: $repairs},
    autogit: {push_ok: $ap, push_fail: $af},
    parliament_auto: {rollbacks: $pr, proposals: $pp},
    parliament: {approved: $pa, vetoed: $pv, rejected: $pj, pending: $pn},
    pm2: {god: $god, online: $pm2on, errored: $pm2er},
    daemons: $daemons
  }' > "$STATE/current.json"

cat "$STATE/current.json"
