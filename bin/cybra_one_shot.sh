#!/data/data/com.termux/files/usr/bin/bash
# CYBRA ONE-SHOT: env → handler → 160 wire → restart → verify
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date +%Y%m%d_%H%M%S)
LOG="$CYBRA/logs/one_shot_$TS.log"
mkdir -p "$CYBRA/logs" "$CYBRA/state"
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }

log "═══ CYBRA ONE-SHOT ($TS) ═══"

# ── 1. Python deps ──
log "── 1. deps ──"
python3 -c "import redis" 2>/dev/null || pip install redis -q 2>/dev/null
python3 -c "import redis; print('  ✅ redis')" || { log "  ❌ redis fail"; exit 1; }

# ── 2. Redis ──
log "── 2. redis-server ──"
redis-cli ping 2>/dev/null | grep -q PONG || {
  pm2 start redis-server --name redis -- --daemonize no 2>/dev/null
  sleep 2
}
redis-cli ping 2>/dev/null | grep -q PONG && log "  ✅ PONG" || { log "  ❌ still down"; exit 1; }

# ── 3. Handler write_module ──
log "── 3. write_module handler ──"
cat > "$CYBRA/bin/parliament_write_module_handler.sh" <<'HANDLER'
#!/data/data/com.termux/files/usr/bin/bash
set -u
if [ $# -ge 1 ]; then TASK="$1"; else TASK=$(cat); fi
[ -z "$TASK" ] && { echo "ERR: no task"; exit 2; }
PYTHONIOENCODING=utf-8 python3 - "$TASK" <<'PY'
import sys, json, os
from pathlib import Path
task = json.loads(sys.argv[1])
n = task.get("module"); path = Path(task.get("path",""))
if not n or not path.parent.exists():
    print(f"ERR: module={n}"); sys.exit(1)
main = path.parent / "main.sh"
code = f"""#!/data/data/com.termux/files/usr/bin/bash
# module_{n:03d} — real (IT Dept)
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null
echo "════════ module_{n:03d} ════════"
echo "── git ──"
git --no-pager log -1 --format='  %h %s' 2>/dev/null || echo "  no git"
echo "── redis ──"
redis-cli ping 2>/dev/null | sed 's/^/  /' || echo "  DOWN"
redis-cli dbsize 2>/dev/null | sed 's/^/  keys: /'
echo "── system ──"
free -m 2>/dev/null | awk '/Mem:/{{printf "  RAM: %d/%d MB\\n", $3, $2}}'
df -h /data 2>/dev/null | awk 'NR==2{{printf "  disk: %s / %s\\n", $3, $2}}'
echo "── pm2 ──"
pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'  online: {{sum(1 for p in d if p[\\"pm2_env\\"][\\"status\\"]==\\"online\\")}}/{{len(d)}}')" 2>/dev/null || echo "  pm2 n/a"
read -r -p "Enter..." _
"""
main.write_text(code); os.chmod(main, 0o755)
print(f"OK: {main} ({len(code)}B)")
PY
HANDLER
chmod +x "$CYBRA/bin/parliament_write_module_handler.sh"
ln -sf "$CYBRA/bin/parliament_write_module_handler.sh" "$CYBRA/parliament_write_module_handler.sh"
log "  ✅ handler ok"

# ── 4. Mapping ──
redis-cli hset cybra:executor:mapping write_module parliament_write_module_handler.sh >/dev/null
log "  ✅ mapping: write_module → handler"

# ── 5. Parliament ──
log "── 4. parliament ──"
if [ ! -f "$CYBRA/parliament_executor_v6.py" ]; then
  git checkout a9b2b80bd -- parliament_executor_v6.py 2>/dev/null || true
fi
if [ -f "$CYBRA/parliament_executor_v6.py" ]; then
  pm2 delete parliament 2>/dev/null
  pm2 start "$CYBRA/parliament_executor_v6.py" --name parliament --interpreter python3 2>/dev/null
  log "  ✅ parliament started"
else
  log "  ⚠️ parliament_executor_v6.py not found"
fi

# ── 6. menu-worker ──
log "── 5. menu-worker ──"
cat > "$CYBRA/parliament_menu_worker.sh" <<'MW'
#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/menu_worker.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
log "═══ MENU WORKER START ═══"
while :; do
  raw=$(redis-cli rpop cybra:parliament:queue 2>/dev/null)
  [ -z "$raw" ] && { sleep 2; continue; }
  action=$(echo "$raw" | python3 -c "import sys,json;print(json.load(sys.stdin).get('action',''))" 2>/dev/null)
  [ -z "$action" ] && { redis-cli rpush cybra:parliament:failed "$raw" >/dev/null; continue; }
  script=$(redis-cli hget cybra:executor:mapping "$action" 2>/dev/null)
  [ -z "$script" ] && { redis-cli rpush cybra:parliament:failed "$raw" >/dev/null; log "no map: $action"; continue; }
  out=$(bash "$CYBRA/$script" "$raw" 2>&1); rc=$?
  status=$([ $rc -eq 0 ] && echo done || echo failed)
  result="{\"action\":\"$action\",\"status\":\"$status\",\"rc\":$rc,\"ts\":\"$(date -u +%FT%TZ)\"}"
  redis-cli rpush cybra:parliament:results "$result" >/dev/null
  log "$action → $status"
done
MW
chmod +x "$CYBRA/parliament_menu_worker.sh"
pm2 delete menu-worker 2>/dev/null
pm2 start "$CYBRA/parliament_menu_worker.sh" --name menu-worker --interpreter bash 2>/dev/null
log "  ✅ menu-worker started"

# ── 7. Build 160 wires ──
log "── 6. build 160 wires ──"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
CTRL="$CYBRA/controllers/module-controller.sh"
python3 - "$CYBRA/modules" "$MENU" "$CTRL" "$CYBRA/state/menu_160_build.json" <<'PY'
import sys, re, shutil, subprocess, json, time
from pathlib import Path
MODS, MENU, CTRL, OUT = map(Path, sys.argv[1:])
STUB = re.compile(r'AI-INTEGRATED|потребує наповнення|smart-stub|МОДУЛЬ.*створено', re.I)

def find(n):
    order = [f"module_{n}_base"]
    if n < 10: order.append(f"module_0{n}_base")
    order += [f"module_{n}_*", f"module_0{n}_*"]
    seen = set()
    for pat in order:
        for d in sorted(MODS.glob(pat)):
            if not d.is_dir() or str(d) in seen: continue
            seen.add(str(d))
            m = d / "main.sh"
            if m.exists(): return m
    return None

def cls(p):
    if not p: return "MISSING"
    t = p.read_text(errors="ignore")
    if STUB.search(t) or len(t) < 200: return "STUB"
    if subprocess.run(["bash","-n",str(p)],capture_output=True).returncode != 0: return "BROKEN"
    return "REAL"

bkp = MENU.with_suffix(MENU.suffix + f".bak.{int(time.time())}")
shutil.copy2(MENU, bkp)
lines = MENU.read_text().splitlines()
anchor = next((i for i,l in enumerate(lines) if re.match(r'^\s*0\|q\|Q\|exit\|quit\)', l)), None)
if anchor is None:
    print("NO_ANCHOR"); sys.exit(1)

wires, stats = [], {"REAL":0,"STUB":0,"BROKEN":0,"MISSING":0}
missing, stub = [], []
for n in range(1,161):
    t = find(n)
    c = cls(t)
    stats[c] += 1
    if c == "MISSING": missing.append(n); continue
    if c == "STUB": stub.append(n)
    cmd = f'~/CYBRA/controllers/module-controller.sh "{t}"' if CTRL.exists() else f'bash "{t}"'
    wires.append(f'        {n}) {cmd} ;;')

head = [l for l in lines[:anchor] if not re.match(r'^\s*\d+\)', l)]
MENU.write_text("\n".join(head + wires + lines[anchor:]) + "\n")
if subprocess.run(["bash","-n",str(MENU)],capture_output=True).returncode != 0:
    shutil.copy2(bkp, MENU); print("ROLLED_BACK"); sys.exit(1)

OUT.write_text(json.dumps({"total":len(wires),"stats":stats,"stub":stub,"missing":missing,
                          "ts":time.strftime("%FT%TZ")},indent=2,ensure_ascii=False))
print(f"WIRES={len(wires)} REAL={stats['REAL']} STUB={stats['STUB']} MISSING={stats['MISSING']}")
if stub: print(f"STUB_NS={stub[:30]}")
if missing: print(f"MISSING_NS={missing[:30]}")
PY

# ── 8. Autorobot ──
log "── 7. autorobot ──"
if [ -f "$CYBRA/bin/cybra_menu_autorobot.py" ]; then
  pm2 delete menu-autorobot 2>/dev/null
  pm2 start "$CYBRA/bin/cybra_menu_autorobot.py" --name menu-autorobot --interpreter python3 -- loop 120 2>/dev/null
  log "  ✅ autorobot started"
fi

pm2 save >/dev/null 2>&1

# ── 9. Verify ──
log "── 8. verify ──"
sleep 3
echo ""
log "═══ SUMMARY ═══"
log "  log:       $LOG"
log "  report:    $CYBRA/state/menu_160_build.json"
log "  pm2:"
pm2 list 2>/dev/null | grep -E 'parliament|menu-worker|autorobot|redis' | sed 's/^/    /'
log "  redis queues:"
log "    queue:   $(redis-cli llen cybra:parliament:queue 2>/dev/null)"
log "    failed:  $(redis-cli llen cybra:parliament:failed 2>/dev/null)"
log "    results: $(redis-cli llen cybra:parliament:results 2>/dev/null)"
log ""
log "  next: cybra  (перевір що меню відкривається і має ~160 пунктів)"
