#!/usr/bin/env python3
import os, re, sys, json, subprocess, shutil, time
from pathlib import Path
from datetime import datetime, timezone
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
STATE = CYBRA / "state"; HIST = STATE/"evo_scores.jsonl"
BASELINE = STATE/"evo_baseline.json"; LOCK = STATE/"evo.lock"
BACKUP = STATE/"evo_backups"; WEAK = STATE/"evo_weakest.json"
LOG = CYBRA/"logs/evo_controller.log"
for d in (STATE, BACKUP, LOG.parent): d.mkdir(parents=True, exist_ok=True)
CFG = {"threshold_rollback":-3.0,"threshold_lock":3.0,"weak_score":90,
       "upgrade_max":10,"restore_min_delta":10,"loop_interval":600,"mode":"auto"}
REAL_RE = re.compile(r'redis-cli|git --no-pager|pm2 jlist|python3 |cybra_|sqlite|curl|fidic', re.I)
STUB_RE = re.compile(r'AI-INTEGRATED|потребує наповнення|smart-stub v1|МОДУЛЬ.*створено заново', re.I)
PREMIUM = r'''#!/data/data/com.termux/files/usr/bin/bash
# module_{n:03d} — premium (evo controller)
set -euo pipefail
CYBRA="${{CYBRA:-$HOME/CYBRA}}"
LOG="$CYBRA/logs/module_{n:03d}.log"; mkdir -p "$(dirname "$LOG")"
log() {{ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }}
err() {{ log "ERR: $*"; echo "  ❌ $*" >&2; return 1; }}
trap 'err "line $LINENO rc=$?"' ERR
cmd_git() {{ echo "── git ──"; git --no-pager log -1 --format='  %h %s' 2>/dev/null; echo "  changes: $(git -C "$CYBRA" status --porcelain 2>/dev/null | wc -l)"; }}
cmd_redis() {{ echo "── redis ──"; echo "  $(redis-cli ping 2>/dev/null || echo DOWN)"; echo "  keys: $(redis-cli dbsize 2>/dev/null || echo 0)"; }}
cmd_system() {{ echo "── system ──"; free -m 2>/dev/null | awk '/Mem:/{{printf "  RAM: %d/%d MB\\n",$3,$2}}'; df -h /data 2>/dev/null | awk 'NR==2{{printf "  disk: %s/%s\\n",$3,$2}}'; }}
cmd_pm2() {{ echo "── pm2 ──"; pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'  online: {{sum(1 for p in d if p[\\"pm2_env\\"][\\"status\\"]==\\\"online\\\")}}/{{len(d)}}')" 2>/dev/null || echo "  n/a"; }}
usage() {{ echo "usage: $0 [git|redis|sys|pm2|all]"; }}
main() {{ local cmd="${{1:-all}}"; log "START {n:03d} cmd=$cmd"; echo "════ module_{n:03d} ════"; case "$cmd" in git) cmd_git;; redis) cmd_redis;; sys|system) cmd_system;; pm2) cmd_pm2;; all) cmd_git; echo ""; cmd_redis; echo ""; cmd_system; echo ""; cmd_pm2;; -h|--help) usage;; *) usage; return 1;; esac; log "END {n:03d}"; read -r -p "Enter..." _ 2>/dev/null || true; }}
main "$@"
'''
def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{t}] {m}"; print(line, flush=True)
    with open(LOG,"a") as f: f.write(line+"\n")
def now(): return datetime.now(timezone.utc).isoformat()
def parse_menu():
    items = {}
    for line in MENU.read_text(errors="ignore").splitlines():
        m = re.match(r'\s*(\d+)\)\s*(.+)', line)
        if not m: continue
        n = int(m.group(1))
        if n < 1 or n > 160: continue
        pm = re.search(r'"(/data/[^"]+\.sh)"', line)
        if pm: items[n] = Path(pm.group(1))
    return items
def score_file(p):
    if not p or not p.exists(): return {"score":-1,"lines":0}
    t = p.read_text(errors="ignore")
    lines = len(t.splitlines()); calls = len(REAL_RE.findall(t))
    funcs = len(re.findall(r'^\w+\s*\(\)\s*\{', t, re.M))
    has_err = bool(re.search(r'\btrap\b|set -e|set -u|\|\| exit', t))
    has_log = bool(re.search(r'>\s*"\$LOG"|tee -a|log\(\)\s*\{', t))
    has_args = bool(re.search(r'\$\{?[1@#]\}?\b|getopts|case\s+"\$\{?1', t))
    s = lines/10 + calls*5 + funcs*3 + (10 if has_err else 0) + (10 if has_log else 0) + (5 if has_args else 0)
    return {"score": round(s,1), "lines": lines, "calls": calls, "funcs": funcs}
def do_score():
    items = parse_menu(); ts = now(); rows, total = [], 0
    for n in range(1,161):
        p = items.get(n); s = score_file(p) if p else {"score":-1}
        s.update({"n":n,"ts":ts,"path":str(p) if p else ""}); rows.append(s); total += max(0,s["score"])
    avg = round(total/160, 2)
    with open(HIST,"a") as f:
        for r in rows: f.write(json.dumps(r,ensure_ascii=False)+"\n")
    weak = sorted([r for r in rows if 0<=r["score"]<CFG["weak_score"]], key=lambda r: r["score"])
    WEAK.write_text(json.dumps({"ts":ts,"avg":avg,"weakest":weak[:20]},indent=2,ensure_ascii=False))
    return avg, rows, weak
def load_baseline():
    if not BASELINE.exists(): return None
    try: return json.loads(BASELINE.read_text())
    except: return None
def snapshot(tag):
    bkp = BACKUP/f"modules_{tag}_{int(time.time())}.tar.gz"
    subprocess.run(["tar","-czf",str(bkp),"-C",str(CYBRA),"modules"],check=False)
    return bkp
def save_baseline(avg, rows, reason):
    bkp = snapshot("baseline")
    BASELINE.write_text(json.dumps({"locked_at":now(),"avg":avg,"reason":reason,
        "snapshot":str(bkp),"modules":{str(r["n"]):{"score":r["score"]} for r in rows}},
        indent=2,ensure_ascii=False))
    return bkp
def rollback():
    b = load_baseline()
    if not b or not Path(b["snapshot"]).exists(): log("  no snapshot"); return False
    log(f"  rollback from {Path(b['snapshot']).name}")
    subprocess.run(["tar","-xzf",b["snapshot"],"-C",str(CYBRA)],check=False); return True
def git_best(n, cur):
    rels = [f"modules/module_{n:03d}_base/main.sh"]
    for d in (CYBRA/"modules").glob(f"module_0*{n}_*"):
        if d.is_dir(): rels.append(f"modules/{d.name}/main.sh")
    best = None
    for rel in rels:
        r = subprocess.run(["git","log","--all","--format=%H","--",rel],cwd=CYBRA,capture_output=True,text=True)
        for c in r.stdout.splitlines()[:15]:
            s = subprocess.run(["git","show",f"{c}:{rel}"],cwd=CYBRA,capture_output=True,text=True)
            if s.returncode != 0 or not s.stdout: continue
            tmp = STATE/".evo_chk.sh"; tmp.write_text(s.stdout)
            ok = subprocess.run(["bash","-n",str(tmp)],capture_output=True).returncode==0
            tmp.unlink(missing_ok=True)
            if not ok: continue
            t = s.stdout; lines = len(t.splitlines()); calls = len(REAL_RE.findall(t))
            funcs = len(re.findall(r'^\w+\s*\(\)\s*\{', t, re.M))
            has_err = bool(re.search(r'\btrap\b|set -e|set -u|\|\| exit', t))
            has_log = bool(re.search(r'>\s*"\$LOG"|tee -a|log\(\)\s*\{', t))
            has_args = bool(re.search(r'\$\{?[1@#]\}?\b|getopts|case\s+"\$\{?1', t))
            sc = round(lines/10 + calls*5 + funcs*3 + (10 if has_err else 0) + (10 if has_log else 0) + (5 if has_args else 0),1)
            if best is None or sc > best[0]: best = (sc, c[:8], t, rel)
    return best
def try_upgrade(n, path):
    if not path.exists(): return False
    bkp = BACKUP/f"up_{n:03d}_{int(time.time())}.sh"; shutil.copy2(path,bkp)
    path.write_text(PREMIUM.format(n=n)); os.chmod(path,0o755)
    if subprocess.run(["bash","-n",str(path)],capture_output=True).returncode != 0:
        shutil.copy2(bkp,path); return False
    return True
def try_restore(n, path, cur):
    best = git_best(n, cur)
    if not best: return False
    bsc, commit, content, rel = best
    if bsc <= cur + CFG["restore_min_delta"]: return False
    bkp = BACKUP/f"rs_{n:03d}_{int(time.time())}.sh"; shutil.copy2(path,bkp)
    path.write_text(content); os.chmod(path,0o755)
    if subprocess.run(["bash","-n",str(path)],capture_output=True).returncode != 0:
        shutil.copy2(bkp,path); return False
    log(f"    [{n}] restored {cur}→{bsc}"); return True
def cycle():
    if LOCK.exists(): log("cycle: lock"); return
    LOCK.touch()
    try:
        log("═══ EVO CYCLE ═══")
        avg, rows, weak = do_score(); base = load_baseline()
        if not base:
            bkp = save_baseline(avg, rows, "initial")
            log(f"  baseline INIT: {avg} snapshot={bkp.name}"); return
        delta = avg - base["avg"]
        log(f"  avg={avg} base={base['avg']} delta={delta:+.2f}%")
        if delta <= CFG["threshold_rollback"]:
            log(f"  🚨 DEGRADATION {delta:+.2f}%")
            if rollback():
                a2,r2,_ = do_score(); save_baseline(a2,r2,"after_rollback")
                log(f"  new baseline {a2}")
            return
        if CFG["mode"] in ("auto","upgrade-only") and weak:
            up = 0
            for r in weak[:CFG["upgrade_max"]]:
                p = Path(r["path"]) if r.get("path") else None
                if p and p.exists() and try_upgrade(r["n"],p): up += 1
            if up: a2,r2,_ = do_score(); log(f"  upgraded {up}: {avg}→{a2}"); avg,rows=a2,r2; delta = avg-base["avg"]
        if CFG["mode"] in ("auto","restore-only") and weak:
            rs = 0
            for r in weak[:CFG["upgrade_max"]]:
                p = Path(r["path"]) if r.get("path") else None
                if p and p.exists() and try_restore(r["n"],p,r["score"]): rs += 1
            if rs: a2,r2,_ = do_score(); log(f"  restored {rs}: {avg}→{a2}"); avg,rows=a2,r2
        if delta >= CFG["threshold_lock"]:
            bkp = save_baseline(avg,rows,f"evolution_{delta:+.2f}%")
            log(f"  🚀 LOCK {base['avg']}→{avg} snapshot={bkp.name}")
    finally:
        LOCK.unlink(missing_ok=True)
def cmd_status():
    base = load_baseline()
    if not HIST.exists(): print("no history"); return
    lines = HIST.read_text().splitlines(); ts = json.loads(lines[-1])["ts"]
    cur = [json.loads(l) for l in lines if json.loads(l)["ts"]==ts]
    avg = round(sum(r["score"] for r in cur if r["score"]>=0)/160,2)
    print("═══ EVO STATUS ═══")
    print(f"  avg:      {avg}")
    if base:
        d = avg-base["avg"]
        print(f"  baseline: {base['avg']}  delta={d:+.2f}%  [±3%]")
    print(f"  cycles:   {len(lines)//160}  mode={CFG['mode']}")
def cmd_history():
    if not HIST.exists(): print("no history"); return
    by = {}
    for l in HIST.read_text().splitlines():
        r = json.loads(l); by.setdefault(r["ts"],[]).append(r["score"])
    for ts in sorted(by)[-12:]:
        s = [x for x in by[ts] if x>=0]
        print(f"  {ts}  avg={round(sum(s)/len(s),2) if s else 0}  n={len(s)}")
if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv)>1 else "status"
    if cmd=="status": cmd_status()
    elif cmd=="history": cmd_history()
    elif cmd=="cycle": cycle()
    elif cmd=="rollback":
        if rollback():
            a,r,_=do_score(); save_baseline(a,r,"manual"); log(f"manual rollback {a}")
    elif cmd=="loop":
        i = int(sys.argv[2]) if len(sys.argv)>2 else CFG["loop_interval"]
        log(f"═══ EVO LOOP ({i}s, mode={CFG['mode']}) ═══")
        while True:
            try: cycle()
            except Exception as e: log(f"ERR {e}")
            time.sleep(i)
