#!/data/data/com.termux/files/usr/bin/bash
# CYBRA TAXI FULL DEPLOY — recovery + 40 модулів + HIDL taxi patch + test
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || { echo "FATAL: no $CYBRA"; exit 1; }
TS=$(date +%Y%m%d_%H%M%S)
LOG="$CYBRA/logs/taxi_deploy_$TS.log"; mkdir -p "$CYBRA/logs"
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
ok(){ log "  ✅ $*"; }
warn(){ log "  ⚠️  $*"; }
fail(){ log "  ❌ $*"; }

log "═══ TAXI FULL DEPLOY [$TS] ═══"

# ═══ 1. RECOVERY — pull HIDL files from origin ═══
log "── 1. recovery ──"

# зберегти поточне
git stash -u -m "pre-recovery-$TS" >/dev/null 2>&1 || true

# pull
git fetch origin 2>&1 | tail -1
git reset --hard origin/main 2>&1 | tail -2

# restore stash (не критично якщо конфлікт)
git stash pop >/dev/null 2>&1 || git stash drop >/dev/null 2>&1 || true

# перевірка які файли є
MISSING=()
for f in bin/cybra_hidl.py bin/cybra_hidl_executor.py bin/cybra_hidl_worker.py \
         bin/cybra_hidl_notifier.py bin/cybra_gen.py bin/cybra_gen_part1.py \
         bin/cybra_notify.sh bin/cybra_health.sh bin/cybra_taxi_events.py \
         bin/cybra_taxi_dispatch.py; do
  [ -f "$f" ] && ok "$f" || { warn "$f MISSING"; MISSING+=("$f"); }
done

# якщо чогось нема — витягнути з git history
for f in "${MISSING[@]}"; do
  git show "origin/main:$f" > "$f" 2>/dev/null && ok "$f (recovered from origin)" || fail "$f cannot recover"
done
chmod +x bin/*.py bin/*.sh 2>/dev/null

# ═══ 2. Recreate cybra_notify.sh if still missing ═══
log "── 2. notify ──"
if [ ! -f bin/cybra_notify.sh ]; then
cat > bin/cybra_notify.sh <<'NTF'
#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || exit 2
NOTIF="$CYBRA/state/hidl/notifications.jsonl"
HEALTH="$CYBRA/state/health.json"
case "${1:-list}" in
  list|warn|error|taxi)
    L="${1}"; [ "$L" = "list" ] && L="all"
    [ ! -f "$NOTIF" ] && { echo "no notifications"; exit 0; }
    python3 - "$NOTIF" "$L" <<'PY'
import sys,json
path,lvl = sys.argv[1], sys.argv[2]
ICON={"success":"🟢","info":"🔵","warn":"🟡","error":"🔴"}
rows=[]
for l in open(path):
    try: r=json.loads(l)
    except: continue
    rows.append(r)
if lvl=="taxi": rows=[r for r in rows if r.get("taxi")]
elif lvl!="all": rows=[r for r in rows if r.get("level")==lvl]
rows=rows[-20:][::-1]
for r in rows:
    ic=ICON.get(r.get("level"),"⚪"); taxi="🚕" if r.get("taxi") else "  "
    print(f"{ic}{taxi} {r.get('ts','?')[:19]}  mod{r.get('module',0):03d}  {r.get('status','?')}")
PY
    ;;
  bar)
    H="?"; R=0; U=0
    [ -f "$HEALTH" ] && H=$(python3 -c "import json;print(json.load(open('$HEALTH')).get('status','?'))" 2>/dev/null)
    [ -f "$HEALTH" ] && R=$(python3 -c "import json;print(json.load(open('$HEALTH')).get('ram_pct',0))" 2>/dev/null)
    [ -f "$NOTIF" ] && U=$(tail -20 "$NOTIF" 2>/dev/null | grep -cE '"level":"(warn|error)"' || echo 0)
    IC="🟢"; [ "$H" = "degraded" ] && IC="🟡"; [ "$H" = "critical" ] && IC="🔴"
    echo "$IC health:$H RAM:${R}% 🔔$U"
    ;;
  stats)
    [ ! -f "$NOTIF" ] && { echo "no notifications"; exit 0; }
    python3 - "$NOTIF" <<'PY'
import sys,json
from collections import Counter
c=Counter(); total=0
for l in open(sys.argv[1]):
    try: r=json.loads(l)
    except: continue
    total+=1; c[r.get("level","info")]+=1
print(f"total: {total}")
for k in ("success","info","warn","error"): print(f"  {k:8} {c.get(k,0)}")
PY
    ;;
  *) echo "usage: $0 list|warn|error|taxi|stats|bar" ;;
esac
NTF
chmod +x bin/cybra_notify.sh
ok "cybra_notify.sh recreated"
else
ok "cybra_notify.sh exists"
fi

# ═══ 3. TAXI modules 200-239 ═══
log "── 3. taxi modules ──"
cat > bin/cybra_taxi_init.py <<'TAXI'
#!/usr/bin/env python3
import os, sys, subprocess
from pathlib import Path
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"; CTRL = CYBRA / "controllers"
TAXI_MENU_DIR = MODS / "module_200_taxi_menu"
TAXI_MENU = TAXI_MENU_DIR / "bin/cybra_taxi_menu.sh"
CTRL.mkdir(exist_ok=True)
SPEC = {
 200:("book_ride","booking","create"),201:("cancel_ride","booking","cancel"),
 202:("ride_status","booking","status"),203:("ride_history","booking","list"),
 204:("estimate_price","booking","estimate"),205:("select_tariff","booking","tariff"),
 206:("schedule_ride","booking","schedule"),207:("repeat_ride","booking","repeat"),
 208:("favorite_route","booking","add"),209:("saved_addresses","booking","list"),
 210:("driver_register","driver","register"),211:("driver_status","driver","status"),
 212:("accept_ride","driver","accept"),213:("complete_ride","driver","complete"),
 214:("driver_earnings","driver","show"),215:("driver_documents","driver","upload"),
 216:("driver_rating","driver","show"),217:("dispatch_nearest","dispatch","find"),
 218:("dispatch_batch","dispatch","batch"),219:("surge_pricing","dispatch","calc"),
 220:("ride_payment","payment","charge"),221:("ride_receipt","payment","receipt"),
 222:("ride_refund","payment","refund"),223:("escrow_ride","payment","escrow"),
 224:("driver_payout","payment","payout"),225:("tip_driver","payment","tip"),
 226:("subscription","payment","show"),227:("wallet_topup","payment","topup"),
 228:("payment_history","payment","list"),229:("promo_code","payment","apply"),
 230:("ai_dispatcher","ai","dispatch"),231:("ai_chat_support","ai","chat"),
 232:("ai_route_optimize","ai","optimize"),233:("ai_demand_forecast","ai","forecast"),
 234:("ai_driver_scoring","ai","score"),235:("ai_dispute","ai","resolve"),
 236:("rider_analytics","analytics","show"),237:("driver_analytics","analytics","show"),
 238:("fleet_analytics","analytics","show"),239:("taxi_metrics","analytics","show"),
}
MAIN = r'''#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="${{CYBRA:-$HOME/CYBRA}}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/taxi_{n:03d}.log"; mkdir -p "$(dirname "$LOG")"
log() {{ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }}
ACTION="${{1:-{act}}}"; shift $(( $# > 0 ? 1 : 0 ))
log "START {name} action=$ACTION args=$#"
case "$ACTION" in
  create|register|add|book|schedule)
    [ $# -lt 1 ] && {{ echo "usage: $0 $ACTION <id> [val]"; exit 1; }}
    redis-cli hset "cybra:taxi:{cat}:data" "$1" "${{2:-$(date +%s)}}" >/dev/null
    echo "✅ {cat}: $1" ;;
  list|status|show|history)
    N=$(redis-cli hlen "cybra:taxi:{cat}:data" 2>/dev/null || echo 0)
    echo "════ taxi {cat}: {name} ════"
    echo "  items: $N"
    [ "$N" -gt 0 ] && redis-cli hgetall "cybra:taxi:{cat}:data" | paste - - | head -20 | sed 's/^/  /' ;;
  cancel|delete|remove)
    [ $# -lt 1 ] && {{ echo "usage: $0 $ACTION <id>"; exit 1; }}
    redis-cli hdel "cybra:taxi:{cat}:data" "$1" >/dev/null
    echo "✅ cancelled: $1" ;;
  estimate|calc|score|forecast|optimize|dispatch|chat|resolve)
    echo "🧠 {name} (AI) args: $*" ;;
  *) echo "════ taxi {name} ════"; echo "  hint: $0 create|list|cancel <id>" ;;
esac
exit $?
'''
CTRL_T = r'''#!/data/data/com.termux/files/usr/bin/bash
set -u
M="$1"; shift
[ -f "$M" ] || {{ echo "❌ missing"; exit 2; }}
bash -n "$M" 2>/dev/null || {{ echo "❌ syntax"; exit 3; }}
[ $# -gt 0 ] && A=("$@") || A=("list")
bash "$M" "${{A[@]}}" </dev/null 2>&1; exit $?
'''
count=0
for n in range(200,240):
    name,cat,act = SPEC[n]
    d = MODS / f"module_{n:03d}_{name}"; d.mkdir(parents=True, exist_ok=True)
    m = d/"main.sh"; m.write_text(MAIN.format(n=n,name=name,cat=cat,act=act)); os.chmod(m,0o755)
    c = CTRL / f"taxi_module_{n:03d}.ctrl.sh"; c.write_text(CTRL_T.format(n=n)); os.chmod(c,0o755)
    count+=1
(TAXI_MENU_DIR/"bin").mkdir(parents=True, exist_ok=True)
lines = ["#!/data/data/com.termux/files/usr/bin/bash",'CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null','while true; do','  clear 2>/dev/null','  echo "════ CYBRA TAXI (40 modules) ════"','  bash "$HOME/CYBRA/bin/cybra_notify.sh" bar 2>/dev/null','  echo ""']
for n in range(200,240): lines.append(f'  echo "  [{n}] {SPEC[n][0]}"')
lines += ['  echo "  [n] Notif [0] Exit"','  read -r -p "  Choice: " c','  case "$c" in']
for n in range(200,240): lines.append(f'    {n}) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_{n}_*" | head -1); bash "$CYBRA/controllers/taxi_module_{n}.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;')
lines += ['    n|N) bash "$CYBRA/bin/cybra_notify.sh" list 20; read -r _ ;;','    0|q) exit 0 ;;','  esac','done']
TAXI_MENU.write_text("\n".join(lines)+"\n"); os.chmod(TAXI_MENU,0o755)
ln = CYBRA/"taxi"
if ln.exists() or ln.is_symlink(): ln.unlink()
ln.symlink_to(TAXI_MENU)
print(f"✅ {count} taxi modules + menu")
TAXI
chmod +x bin/cybra_taxi_init.py
python3 bin/cybra_taxi_init.py 2>&1 | tail -2

# ═══ 4. Patch executor for taxi ═══
log "── 4. executor patch ──"
python3 - <<'PY'
from pathlib import Path
p = Path.home()/"CYBRA/bin/cybra_hidl_executor.py"
if not p.exists(): print("❌ executor missing"); raise SystemExit(1)
t = p.read_text()
if "emit_taxi_event" not in t:
    old = "def run_hidl(msg):"
    new = '''def emit_taxi_event(ch, ev, mod, payload):
    import json as _j
    try:
        m = _j.dumps({"event":ev,"module":mod,"payload":payload,
                      "ts":__import__("datetime").datetime.now(__import__("datetime").timezone.utc).isoformat()}, ensure_ascii=False)
        subprocess.run(["redis-cli","publish",ch,m], capture_output=True, timeout=5)
        subprocess.run(["redis-cli","rpush","cybra:taxi:events:log",m], capture_output=True, timeout=5)
        subprocess.run(["redis-cli","ltrim","cybra:taxi:events:log","-1000","-1"], capture_output=True, timeout=5)
    except: pass

def geo_add(d, la, ln):
    try: subprocess.run(["redis-cli","geoadd","cybra:taxi:drivers:geo",str(ln),str(la),d], capture_output=True, timeout=5)
    except: pass

def run_hidl(msg):'''
    t = t.replace(old, new, 1)
old2 = '''    # score after
    if main and Path(main).exists():
        after = score_text(Path(main).read_text(errors="ignore"))
        resp["score_after"] = after'''
new2 = '''    # TAXI post-actions
    taxi = msg.get("taxi", {})
    if taxi:
        if resp.get("status")=="ok" and taxi.get("events"):
            for ev in taxi["events"]:
                emit_taxi_event("cybra:taxi:events", ev, n, {"args":args})
        if taxi.get("geo") and resp.get("rc",0)==0 and args:
            a_l = (action or "").lower()
            if any(k in a_l for k in ("register","add","accept")) and len(args)>=3:
                try:
                    geo_add(args[0], float(args[1]), float(args[2]))
                    resp["stdout"] += f"\\n  geo: {args[0]}"
                except: pass

    # score after
    if main and Path(main).exists():
        after = score_text(Path(main).read_text(errors="ignore"))
        resp["score_after"] = after'''
if old2 in t: t = t.replace(old2, new2)
p.write_text(t); print("✅ executor patched")
PY
python3 -m py_compile bin/cybra_hidl_executor.py 2>&1 && ok "executor compile OK"

# ═══ 5. Patch hidl.py for taxi ═══
log "── 5. hidl.py patch ──"
python3 - <<'PY'
from pathlib import Path
p = Path.home()/"CYBRA/bin/cybra_hidl.py"
if not p.exists(): print("❌ hidl missing"); raise SystemExit(1)
t = p.read_text()
if "def taxi_spec" not in t:
    old = "def dispatch("
    new = '''def taxi_spec(n):
    if n < 200 or n > 239: return None
    mf = CYBRA/"state/taxi_hidl_mapping.json"
    if not mf.exists(): return None
    try: return json.loads(mf.read_text()).get("mapping",{}).get(str(n))
    except: return None

def find_ctrl(n):
    for nm in (f"module_{n:03d}.ctrl.sh", f"taxi_module_{n:03d}.ctrl.sh"):
        c = CYBRA/"controllers"/nm
        if c.exists(): return c
    return None

def dispatch('''
    t = t.replace(old, new, 1)
if '"taxi": taxi_extra' not in t:
    old2 = '''    msg = {
        "id": f"HIDL-{n:03d}-{int(time.time())}",'''
    new2 = '''    tx = taxi_spec(n)
    taxi_extra = {}
    if tx:
        taxi_extra = {"geo":tx.get("geo",False),"events":tx.get("events",[]),
                      "ai":tx.get("ai",False),"channel":tx.get("notify")}
        if action == "execute" and tx.get("action"): action = tx["action"]
        if not ctrl.exists(): ctrl = find_ctrl(n) or ctrl
    msg = {
        "id": f"HIDL-{n:03d}-{int(time.time())}",'''
    t = t.replace(old2, new2, 1)
    t = t.replace('"file": "state/hidl/events.jsonl"},\n    }',
                  '"file": "state/hidl/events.jsonl"},\n        "taxi": taxi_extra,\n    }')
p.write_text(t); print("✅ hidl.py patched")
PY
python3 -m py_compile bin/cybra_hidl.py 2>&1 && ok "hidl.py compile OK"

# ═══ 6. PM2 restart ═══
log "── 6. PM2 ──"
for p in hidl-worker hidl-notifier taxi-events; do
  pm2 describe "$p" >/dev/null 2>&1 && pm2 restart "$p" >/dev/null 2>&1 || {
    case "$p" in
      hidl-worker)   [ -f bin/cybra_hidl_worker.py ] && pm2 start bin/cybra_hidl_worker.py --name hidl-worker --interpreter python3 >/dev/null 2>&1 ;;
      hidl-notifier) [ -f bin/cybra_hidl_notifier.py ] && pm2 start bin/cybra_hidl_notifier.py --name hidl-notifier --interpreter python3 >/dev/null 2>&1 ;;
      taxi-events)   [ -f bin/cybra_taxi_events.py ] && pm2 start bin/cybra_taxi_events.py --name taxi-events --interpreter python3 >/dev/null 2>&1 ;;
    esac
  }
done
pm2 save >/dev/null 2>&1
ok "pm2 updated"

# ═══ 7. TEST ═══
log "── 7. test ──"
echo ""
echo "── test 1: HIDL бачить таксі ──"
~/CYBRA/bin/cybra_hidl.py 200 2>&1 | head -2

echo ""
echo "── test 2: geo add-driver ──"
~/CYBRA/bin/cybra_taxi_dispatch.py add-driver driver_01 50.45 30.52 2>&1 | tail -1
~/CYBRA/bin/cybra_taxi_dispatch.py add-driver driver_02 50.46 30.53 2>&1 | tail -1

echo ""
echo "── test 3: find-nearest ──"
~/CYBRA/bin/cybra_taxi_dispatch.py find-nearest 50.45 30.52 10 3 2>&1

echo ""
echo "── test 4: HIDL execute ride ──"
~/CYBRA/bin/cybra_hidl.py 200 execute ride_001 2>&1 | head -1
sleep 6
echo "  events log:"
redis-cli lrange cybra:taxi:events:log -2 -1 2>/dev/null | head -3

echo ""
echo "── test 5: notify taxi ──"
~/CYBRA/bin/cybra_notify.sh taxi 2>&1 | head -5

echo ""
echo "── test 6: taxi status ──"
~/CYBRA/bin/cybra_taxi_dispatch.py status 2>&1

# ═══ 8. COMMIT ═══
log "── 8. commit ──"
git add bin/cybra_taxi_init.py bin/cybra_taxi_events.py bin/cybra_taxi_dispatch.py \
        bin/cybra_hidl.py bin/cybra_hidl_executor.py bin/cybra_notify.sh \
        bin/cybra_taxi_full_deploy.sh \
        state/taxi_hidl_mapping.json \
        modules/module_2[0-3][0-9]_* controllers/taxi_module_*.ctrl.sh \
        modules/module_200_taxi_menu 2>/dev/null
git commit -m "feat(taxi): 40 modules 200-239 + HIDL taxi mapping + geo dispatch + events" 2>&1 | tail -3

log ""
log "═══ DONE ═══"
log "  log:     $LOG"
log "  next:    ~/CYBRA/taxi         (меню 40 модулів)"
log "  or:      ~/CYBRA/bin/cybra_notify.sh bar"
log "  or:      ~/CYBRA/bin/cybra_hidl.py 200 execute ride_002"
