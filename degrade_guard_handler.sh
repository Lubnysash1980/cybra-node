#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"
mkdir -p state/degrade_guard state/snapshots/good

BASELINE="state/degrade_guard/baseline.json"
GOOD="state/snapshots/good/latest.tar.gz"
INCIDENTS="state/degrade_guard/incidents.log"
THRESHOLD=3.0

pct_now(){
  python3 - <<'PY'
import json, subprocess
from pathlib import Path
m = Path.home()/"CYBRA/state/snapshots/_master.json"
if not m.exists(): print(0); raise SystemExit
try:
    d = json.loads(m.read_text())
    print(d.get("pct", 0))
except: print(0)
PY
}

dash_cnt(){ grep -l '── git ──' modules/module_*/main.sh 2>/dev/null | wc -l; }
nl_cnt(){ grep -l '\\\\n' modules/module_*/main.sh 2>/dev/null | wc -l; }

save_snapshot(){
  tar -czf "$GOOD" modules controllers \
    modules/module_19_contract_tui_menu/bin/cybra_menu.sh \
    state/snapshots/_master.json 2>/dev/null
}

CUR_PCT=$(pct_now)
CUR_DASH=$(dash_cnt)
CUR_NL=$(nl_cnt)

# ─── перший запуск: baseline ───
if [ ! -f "$BASELINE" ]; then
  python3 -c "
import json, time
json.dump({'pct': $CUR_PCT, 'dashboard': $CUR_DASH, 'nl': $CUR_NL,
           'ts': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())},
          open('$BASELINE','w'))
"
  save_snapshot
  echo "{\"ok\":true,\"action\":\"baseline_created\",\"pct\":$CUR_PCT}"
  exit 0
fi

# ─── поточний стан vs baseline ───
BASE_PCT=$(python3 -c "import json;print(json.load(open('$BASELINE'))['pct'])")
BASE_DASH=$(python3 -c "import json;print(json.load(open('$BASELINE')).get('dashboard',0))")
BASE_NL=$(python3 -c "import json;print(json.load(open('$BASELINE')).get('nl',0))")
DELTA=$(awk -v a="$BASE_PCT" -v b="$CUR_PCT" 'BEGIN{printf "%.2f", b-a}')
DASH_DELTA=$((CUR_DASH - BASE_DASH))
NL_DELTA=$((CUR_NL - BASE_NL))

if [ "$DASH_DELTA" -gt 0 ] || [ "$NL_DELTA" -gt 0 ]; then
  echo "  dashboard/nl деградація: dash+$DASH_DELTA nl+$NL_DELTA"
elif awk -v d="$DELTA" 'BEGIN{exit !(d >= 0)}'; then
  python3 -c "
import json, time
json.dump({'pct': $CUR_PCT, 'dashboard': $CUR_DASH, 'nl': $CUR_NL,
           'ts': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())},
          open('$BASELINE','w'))
"
  save_snapshot
  echo "{\"ok\":true,\"action\":\"baseline_updated\",\"pct\":$CUR_PCT,\"delta\":$DELTA}"
  exit 0
fi

# мала деградація (<3%) — тільки попередження
OVER=0
if awk -v d="$DELTA" -v t="$THRESHOLD" 'BEGIN{exit !(d < -t)}'; then OVER=1; fi
if [ "$DASH_DELTA" -gt 0 ] || [ "$NL_DELTA" -gt 0 ]; then OVER=1; fi
if [ "$OVER" -eq 0 ]; then
  echo "{\"ok\":true,\"action\":\"warning\",\"pct\":$CUR_PCT,\"delta\":$DELTA,\"threshold\":-$THRESHOLD}"
  exit 0
fi

# ═══ ДЕГРАДАЦІЯ ≥ 3% ═══
echo "── DEGRADATION DETECTED ──"
echo "  baseline: $BASE_PCT%  now: $CUR_PCT%  delta: $DELTA%"
echo "  dashboard: $CUR_DASH  \\n: $CUR_NL"

# 1. STOP rewriters
pm2 delete cybra-autopilot cybra-binmix-mixin menu-autorobot cybra-evo-ctrl 2>/dev/null
pm2 save >/dev/null 2>&1

# 2. ROLLBACK зі snapshot
if [ -f "$GOOD" ]; then
  tar -xzf "$GOOD" -C "$HOME/CYBRA" 2>/dev/null
  echo "  ✅ rolled back from snapshot"
fi

# 3. DELETE деградовані (залишкові dashboard/nl після rollback)
for f in $(grep -l '── git ──' modules/module_*/main.sh 2>/dev/null); do
  d=$(dirname "$f"); n=$(basename "$d" | sed -E 's/^module_0*([0-9]+)_?.*/\1/')
  case "$n" in ''|*[!0-9]*) continue ;; esac
  tag=$(basename "$d" | sed -E "s/^module_0*${n}_?//"); [ -z "$tag" ] && tag="base"
  KEY="cybra:mod_${n}:data"
  cat > "$f" <<MOD
#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="\${CYBRA:-\$HOME/CYBRA}"; cd "\$CYBRA" 2>/dev/null || exit 1
ACTION="\${1:-list}"; shift \$(( \$# > 0 ? 1 : 0 ))
KEY="${KEY}"
case "\$ACTION" in
  add|create) [ \$# -lt 1 ] && exit 1; redis-cli hset "\$KEY" "\$1" "\${2:-x}" >/dev/null; echo "✅ \$1" ;;
  list|status) N=\$(redis-cli hlen "\$KEY" 2>/dev/null || echo 0); echo "════ module_$(printf '%03d' "$n") (${tag}) ════"; echo "  items: \$N" ;;
  delete|rm) [ \$# -lt 1 ] && exit 1; redis-cli hdel "\$KEY" "\$1" >/dev/null; echo "✅ \$1" ;;
  *) echo "module_$(printf '%03d' "$n"): add|list|delete" ;;
esac
exit 0
MOD
  chmod +x "$f"
done

# 4. ESCALATE до еволюції через парламент
TOPIC="evo_$(date +%s)"
TASK=$(python3 -c "
import json
print(json.dumps({
  'topic': '$TOPIC', 'type': 'evo_evolution_task', 'action': 'repair',
  'reason': 'degradation_3pct',
  'from_pct': $BASE_PCT, 'to_pct': $CUR_PCT, 'delta': $DELTA,
  'dashboard': $CUR_DASH, 'nl': $CUR_NL,
}))
")
printf '%s' "$TASK" | redis-cli -x rpush cybra:parliament:queue >/dev/null

# 5. Лог інциденту
printf '%s\n' "[$(date -u +%FT%TZ)] DEGRADED $BASE_PCT→$CUR_PCT (Δ$DELTA) dashboard=$CUR_DASH nl=$CUR_NL → evo_evolution_task/$TOPIC" >> "$INCIDENTS"

echo "{\"ok\":true,\"action\":\"degradation_handled\",\"baseline\":$BASE_PCT,\"now\":$CUR_PCT,\"delta\":$DELTA,\"escalated\":\"evo_evolution_task\",\"topic\":\"$TOPIC\"}"
