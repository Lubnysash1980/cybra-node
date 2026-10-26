#!/data/data/com.termux/files/usr/bin/bash
# CYBRA HEALTH — мінімум для підхоплення стану робочості.
# Перевіряє 6 ключових компонентів, піднімає що впало, пише стан у state/health.json.
# Exit: 0 = все OK, 1 = деградація (але лікується), 2 = критично (redis/меню)
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || { echo "FATAL: no $CYBRA"; exit 2; }
STATE="$CYBRA/state/health.json"; LOG="$CYBRA/logs/health.log"
mkdir -p "$(dirname "$STATE")" "$(dirname "$LOG")"

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
PROBLEMS=(); FIXED=(); CRITICAL=0; DEGRADED=0

say(){ printf '%s\n' "$*" | tee -a "$LOG"; }
ok(){   say "  ✅ $*"; }
warn(){ say "  ⚠️  $*"; DEGRADED=$((DEGRADED+1)); PROBLEMS+=("$*"); }
fail(){ say "  ❌ $*"; CRITICAL=$((CRITICAL+1)); PROBLEMS+=("$*"); }
fix(){  say "  🔧 fixed: $*"; FIXED+=("$*"); }

say "═══ CYBRA HEALTH [$TS] ═══"

# ─── 1. Python redis ───
if python3 -c "import redis" 2>/dev/null; then
  ok "python:redis"
else
  warn "python:redis missing"
  pip install redis -q 2>/dev/null && fix "pip install redis" || fail "pip install redis failed"
fi

# ─── 2. Redis ───
if redis-cli ping 2>/dev/null | grep -q PONG; then
  ok "redis:PONG"
else
  warn "redis:DOWN"
  pm2 start redis-server --name redis -- --daemonize no >/dev/null 2>&1
  sleep 3
  if redis-cli ping 2>/dev/null | grep -q PONG; then fix "redis:started"; else fail "redis:cannot start"; fi
fi

# ─── 3. PM2 core processes ───
NEEDED=(parliament menu-worker menu-autorobot cybra-evo-ctrl cybra-autopilot hidl-worker hidl-notifier)
PM2_ONLINE=$(pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(' '.join(p['name'] for p in d if p['pm2_env']['status']=='online'))
except: print('')
" 2>/dev/null)

for proc in "${NEEDED[@]}"; do
  case " $PM2_ONLINE " in
    *" $proc "*)
      ok "pm2:$proc"
      ;;
    *)
      warn "pm2:$proc not online"
      # намагаємось підняти: спершу restart (якщо існує), потім start
      if pm2 describe "$proc" >/dev/null 2>&1; then
        pm2 restart "$proc" >/dev/null 2>&1 && fix "pm2:$proc restarted"
      else
        case "$proc" in
          parliament)        [ -f "$CYBRA/parliament_executor_v6.py" ] && pm2 start "$CYBRA/parliament_executor_v6.py" --name parliament --interpreter python3 >/dev/null 2>&1 && fix "pm2:$proc started" ;;
          menu-worker)       [ -f "$CYBRA/parliament_menu_worker.sh" ] && pm2 start "$CYBRA/parliament_menu_worker.sh" --name menu-worker --interpreter bash >/dev/null 2>&1 && fix "pm2:$proc started" ;;
          menu-autorobot)    [ -f "$CYBRA/bin/cybra_menu_autorobot.py" ] && pm2 start "$CYBRA/bin/cybra_menu_autorobot.py" --name menu-autorobot --interpreter python3 -- loop 120 >/dev/null 2>&1 && fix "pm2:$proc started" ;;
          cybra-evo-ctrl)    [ -f "$CYBRA/bin/cybra_evo_controller.py" ] && pm2 start "$CYBRA/bin/cybra_evo_controller.py" --name cybra-evo-ctrl --interpreter python3 -- loop 600 >/dev/null 2>&1 && fix "pm2:$proc started" ;;
          cybra-autopilot)   [ -f "$CYBRA/bin/cybra_autopilot.py" ] && pm2 start "$CYBRA/bin/cybra_autopilot.py" --name cybra-autopilot --interpreter python3 -- loop 900 >/dev/null 2>&1 && fix "pm2:$proc started" ;;
          hidl-worker)       [ -f "$CYBRA/bin/cybra_hidl_worker.py" ] && pm2 start "$CYBRA/bin/cybra_hidl_worker.py" --name hidl-worker --interpreter python3 >/dev/null 2>&1 && fix "pm2:$proc started" ;;
          hidl-notifier)     [ -f "$CYBRA/bin/cybra_hidl_notifier.py" ] && pm2 start "$CYBRA/bin/cybra_hidl_notifier.py" --name hidl-notifier --interpreter python3 >/dev/null 2>&1 && fix "pm2:$proc started" ;;
        esac
      fi
      ;;
  esac
done

# ─── 4. Menu 160 wires ───
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
if [ -f "$MENU" ]; then
  WIRES=$(grep -cE '^\s*[0-9]+\)\s' "$MENU" 2>/dev/null || echo 0)
  if [ "$WIRES" -ge 160 ]; then
    ok "menu:${WIRES} wires"
  else
    warn "menu:${WIRES}/160 wires"
    if [ -f "$CYBRA/bin/cybra_gen.py" ]; then
      python3 "$CYBRA/bin/cybra_gen.py" >/dev/null 2>&1 && fix "menu:regenerated"
    fi
  fi
else
  fail "menu:file missing"
fi

# ─── 5. Evo baseline ───
BASELINE="$CYBRA/state/evo_baseline.json"
if [ -f "$BASELINE" ]; then
  AVG=$(python3 -c "import json;print(json.load(open('$BASELINE')).get('avg',0))" 2>/dev/null || echo 0)
  ok "evo:baseline avg=$AVG"
else
  warn "evo:no baseline"
  [ -f "$CYBRA/bin/cybra_evo_controller.py" ] && python3 "$CYBRA/bin/cybra_evo_controller.py" cycle >/dev/null 2>&1 && fix "evo:baseline created"
fi

# ─── 6. HIDL queues ───
HIDL_Q=$(redis-cli llen cybra:hidl:queue 2>/dev/null || echo 0)
HIDL_R=$(redis-cli llen cybra:hidl:results 2>/dev/null || echo 0)
if [ "$HIDL_Q" -gt 50 ]; then
  warn "hidl:queue backlog $HIDL_Q"
else
  ok "hidl:queue=$HIDL_Q results=$HIDL_R"
fi

# ─── 7. RAM / disk ───
RAM=$(free -m 2>/dev/null | awk '/Mem:/{printf "%d",$3/$2*100}')
DISK=$(df /data 2>/dev/null | awk 'NR==2{print $4}' | sed 's/[A-Za-z]//g')
# df /data returns "-" or "0" on some Android; fallback to stat
if [ -z "$DISK" ] || [ "$DISK" = "0" ]; then
  DISK=$(df /data 2>/dev/null | tail -1 | awk '{print $4}')
fi
if [ -z "$DISK" ]; then
  # can't measure — skip silently
  ok "disk: n/a"
else
  if [ "${RAM:-0}" -ge 92 ]; then warn "ram:${RAM}% critical"; elif [ "${RAM:-0}" -ge 85 ]; then warn "ram:${RAM}% high"; else ok "ram:${RAM}%"; fi
  if [ "$DISK" -le 500 ]; then warn "disk:${DISK}MB low"; else ok "disk:${DISK}MB free"; fi
fi

# ─── Persist ───
pm2 save >/dev/null 2>&1

# ─── JSON state ───
python3 - "$STATE" "$TS" "$CRITICAL" "$DEGRADED" "$WIRES" "$RAM" "$DISK" "$HIDL_Q" "$HIDL_R" "${PROBLEMS[@]}" -- "${FIXED[@]}" <<'PY'
import sys, json
args = sys.argv[1:]
sep = args.index("--")
state_path, ts, crit, deg, wires, ram, disk, hq, hr = args[:9]
problems = args[9:sep]
fixed = args[sep+1:]
status = "ok" if int(crit)==0 and int(deg)==0 else ("critical" if int(crit)>0 else "degraded")
data = {
    "ts": ts, "status": status,
    "critical": int(crit), "degraded": int(deg),
    "menu_wires": int(wires), "ram_pct": int(ram or 0), "disk_free_mb": int(disk or 0),
    "hidl_queue": int(hq or 0), "hidl_results": int(hr or 0),
    "problems": problems, "fixed": fixed,
}
open(state_path, "w").write(json.dumps(data, indent=2, ensure_ascii=False))
PY

say ""
say "═══ RESULT: $([ $CRITICAL -eq 0 ] && echo 'OK' || echo 'CRITICAL')  (degraded=$DEGRADED, fixed=${#FIXED[@]}) ═══"
say "  state: $STATE"

if [ "$CRITICAL" -gt 0 ]; then exit 2; fi
if [ "$DEGRADED" -gt 0 ]; then exit 1; fi
exit 0
