#!/usr/bin/env python3
"""NO-DEVOLUTION GUARD — постійний, токен-підписаний, авто-вбивця.
- Кожні 30с: вбиває все з devol/degrad/rollback/revert/downgrade.
- -3% score → NUCLEAR KILL (всі non-protected PM2 + процеси) → restore golden modules → resurrect.
- Токен парламенту обов'язковий. Без токена — safe mode (тільки лог).
"""
import os, sys, re, json, time, subprocess, signal, tarfile, shutil
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME/"CYBRA"; BIN = CYBRA/"bin"; PM2 = HOME/".pm2"
STATE = CYBRA/"state"/"nodevol"; GOLDEN_DIR = STATE/"golden"
GOLDEN_TAR = GOLDEN_DIR/"modules_golden.tar.gz"
LOG = PM2/"logs"/"nodevol.log"
TOKEN_F = PM2/"ctl"/"parliament.token"
PEAK_F = STATE/"peak.json"
STATE.mkdir(parents=True, exist_ok=True); GOLDEN_DIR.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

PROTECT_PM2 = {
    "cybra-no-devolution","parliament","redis",
    "cybra-evo-ctrl","cybra-evolution-ctrl","cybra-neuro-ctrl",
    "cybra-oracle-ctrl","cybra-resurrection-ctrl",
    "cybra-api","cybra-token-guard","taxi-events",
    "menu-worker","menu-autorobot","hidl-worker","hidl-notifier",
}
DEVOL_RE = re.compile(r'\b(devol|degrad|rollback|downgrade|revert|backward|dismantl)\w*', re.I)

def log(m):
    try: LOG.open("a").write(f"[{datetime.now(timezone.utc).isoformat()}] {m}\n")
    except: pass

def token_ok():
    if not TOKEN_F.exists(): return False
    try:
        r = subprocess.run(["python3", str(BIN/"parliament_token.py"), "verify",
                            TOKEN_F.read_text().strip()], capture_output=True, timeout=5)
        return r.returncode == 0
    except: return False

def read_score():
    try: return float(json.loads((PM2/"evolution"/"score.json").read_text()).get("score_pct",0))
    except: return 0

def get_peak():
    if PEAK_F.exists():
        try: return float(json.loads(PEAK_F.read_text())["peak"])
        except: pass
    return read_score()

def set_peak(v): PEAK_F.write_text(json.dumps({"peak": v, "ts": time.time()}))

def list_pm2():
    try: return json.loads(subprocess.check_output(["pm2","jlist"], stderr=subprocess.DEVNULL, timeout=10) or b"[]")
    except: return []

def kill_pid(pid):
    try: os.kill(pid, signal.SIGKILL); return True
    except: return False

def scan_procs():
    out=[]
    try: ps = subprocess.check_output(["ps","-eo","pid,args"], stderr=subprocess.DEVNULL, timeout=10).decode()
    except: return out
    for line in ps.splitlines()[1:]:
        parts = line.strip().split(None,1)
        if len(parts)<2: continue
        pid,cmd = parts
        if pid==str(os.getpid()): continue
        if "no_devolution" in cmd or "parliament_token" in cmd: continue
        if any(p in cmd for p in PROTECT_PM2): continue
        if DEVOL_RE.search(cmd): out.append((int(pid), cmd[:150]))
    return out

def scan_pm2():
    return [p["name"] for p in list_pm2()
            if p["name"] not in PROTECT_PM2
            and p.get("pm2_env",{}).get("status")=="online"
            and DEVOL_RE.search(p["name"]+p.get("pm2_env",{}).get("pm_exec_path",""))]

def scan_parliament():
    try: lines = subprocess.check_output(["redis-cli","lrange","cybra:parliament:queue","0","-1"],
                                          stderr=subprocess.DEVNULL, timeout=10).decode().splitlines()
    except: return []
    bad=[]
    for l in lines:
        l=l.strip()
        if not l: continue
        try: t=json.loads(l)
        except: continue
        a=(t.get("action") or t.get("type") or t.get("kind") or "").lower()
        if DEVOL_RE.search(a): bad.append(t.get("id"))
    return bad

def make_golden():
    if not (CYBRA/"modules").exists(): return False
    try:
        with tarfile.open(GOLDEN_TAR,"w:gz") as tar:
            tar.add(CYBRA/"modules", arcname="modules")
        log(f"GOLDEN made {GOLDEN_TAR.stat().st_size//1024}KB")
        return True
    except Exception as e:
        log(f"GOLDEN fail {e}"); return False

def restore_golden():
    if not GOLDEN_TAR.exists(): return False
    try:
        shutil.rmtree(CYBRA/"modules", ignore_errors=True)
        with tarfile.open(GOLDEN_TAR,"r:gz") as tar: tar.extractall(CYBRA)
        log("GOLDEN restored"); return True
    except Exception as e:
        log(f"GOLDEN restore fail {e}"); return False

def nuclear_kill():
    log("═══ NUCLEAR KILL START ═══")
    n_pm2=0; n_proc=0
    # 1. Kill ALL non-protected PM2 (not just devol-named — повне вбивство)
    for p in list_pm2():
        n=p["name"]
        if n in PROTECT_PM2: continue
        if p.get("pm2_env",{}).get("status")=="online":
            subprocess.run(["pm2","delete",n], capture_output=True, timeout=10)
            n_pm2+=1
    # 2. Kill devolution processes
    for pid,cmd in scan_procs():
        if kill_pid(pid): n_proc+=1
    # 3. Restore golden modules
    restored = restore_golden()
    # 4. Resurrect PM2
    subprocess.run(["pm2","resurrect"], capture_output=True, timeout=30)
    log(f"NUCLEAR DONE pm2={n_pm2} proc={n_proc} restored={restored}")
    return n_pm2,n_proc,restored

def purge_parliament(bad_ids):
    if not bad_ids: return
    try:
        all_lines = subprocess.check_output(
            ["redis-cli","lrange","cybra:parliament:queue","0","-1"],
            stderr=subprocess.DEVNULL, timeout=10).decode().splitlines()
        keep = [l for l in all_lines if l.strip() and json.loads(l).get("id") not in bad_ids]
        subprocess.run(["redis-cli","del","cybra:parliament:queue"], capture_output=True)
        for k in keep:
            subprocess.run(["redis-cli","-x","rpush","cybra:parliament:queue",k], capture_output=True)
        log(f"PURGED parliament {len(bad_ids)} tasks")
    except Exception as e: log(f"purge fail {e}")

def tick():
    if not token_ok():
        log("SAFE MODE (no token)")
        for pid,cmd in scan_procs()[:5]: log(f"WOULD KILL {pid} {cmd[:80]}")
        for n in scan_pm2()[:5]: log(f"WOULD DEL {n}")
        return
    score = read_score(); peak = get_peak()
    pct_drop = ((peak-score)/peak*100) if peak>0 else 0
    if pct_drop >= 3.0:
        log(f"TRIGGER -{pct_drop:.2f}% (peak={peak} score={score})")
        nuclear_kill()
        return
    # passive kill
    for pid,cmd in scan_procs():
        if kill_pid(pid): log(f"KILL {pid} {cmd[:80]}")
    for n in scan_pm2():
        subprocess.run(["pm2","delete",n], capture_output=True, timeout=10)
        log(f"DEL pm2 {n}")
    purge_parliament(scan_parliament())
    if score > peak: set_peak(score)
    if not GOLDEN_TAR.exists() and score >= 99: make_golden()

def install():
    if not token_ok(): print("❌ token missing"); return 1
    subprocess.run(["pm2","delete","cybra-no-devolution"], capture_output=True)
    subprocess.run(["pm2","start",str(BIN/"cybra_no_devolution.py"),
                    "--name","cybra-no-devolution","--interpreter","python3"],
                   capture_output=True, timeout=30)
    subprocess.run(["pm2","save"], capture_output=True, timeout=15)
    try: cur = subprocess.check_output(["crontab","-l"], stderr=subprocess.DEVNULL).decode()
    except: cur=""
    keep = [l for l in cur.splitlines() if "cybra_no_devolution" not in l and "cybra-no-devolution" not in l]
    keep.append(f"*/2 * * * * pgrep -f cybra_no_devolution.py >/dev/null || pm2 start cybra-no-devolution 2>/dev/null")
    keep.append(f"@reboot sleep 60 && pm2 start cybra-no-devolution 2>/dev/null")
    subprocess.run(["crontab","-"], input="\n".join(keep).encode(), timeout=10)
    # nohup backup
    subprocess.run(["bash","-c",f"pgrep -f cybra_no_devolution.py >/dev/null || nohup {BIN}/cybra_no_devolution.py >>{LOG} 2>&1 &"])
    print("✅ INSTALLED: PM2 + cron */2 + @reboot + nohup")
    print(f"   log: {LOG}")
    return 0

if __name__ == "__main__":
    a = sys.argv[1:]
    if "--install" in a: sys.exit(install())
    elif "--dry-run" in a:
        print(f"token:  {'OK' if token_ok() else 'MISSING — safe mode'}")
        print(f"score:  {read_score()}%  peak: {get_peak()}%")
        print(f"golden: {'exists' if GOLDEN_TAR.exists() else 'NO (make at score>=99)'}")
        procs = scan_procs()
        print(f"procs to kill: {len(procs)}")
        for pid,cmd in procs[:10]: print(f"  {pid} {cmd[:90]}")
        print(f"pm2 devol: {scan_pm2()[:10]}")
        print(f"parliament devol: {scan_parliament()[:5]}")
    elif "--once" in a: tick()
    elif "--make-golden" in a: make_golden()
    else:
        log("DAEMON START")
        while True:
            try: tick()
            except Exception as e: log(f"err {e}")
            time.sleep(30)
