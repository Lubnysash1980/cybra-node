#!/usr/bin/env python3
"""AUTOPILOT: 7-day unattended maintenance."""
import os, re, sys, json, subprocess, time, shutil, tarfile
from pathlib import Path
from datetime import datetime, timezone, timedelta

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
LOG   = CYBRA / "logs/autopilot.log"
STATE = CYBRA / "state/autopilot.json"
CFG = {
    "ram_pause":       85,    # % — pause heavy writers
    "ram_critical":    92,    # % — kill non-essential
    "disk_min_mb":     2000,  # pause if less
    "log_keep_days":   7,
    "task_keep_hours": 48,
    "failed_keep":     50,    # max items in failed queue
    "heartbeat_hours": 6,     # write heartbeat
    "interval":        900,   # 15 min
}
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{t}] {m}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

def sh(cmd, timeout=20):
    try:
        return subprocess.run(cmd, shell=True, capture_output=True, text=True,
                             timeout=timeout, cwd=CYBRA)
    except Exception:
        return None

def ram_pct():
    try:
        t = open("/proc/meminfo").read()
        total = int([l for l in t.splitlines() if "MemTotal" in l][0].split()[1])
        avail = int([l for l in t.splitlines() if "MemAvailable" in l][0].split()[1])
        return round((total - avail) * 100 / total, 1)
    except: return 0

def disk_mb():
    try:
        s = shutil.disk_usage("/data")
        return s.free // (1024*1024)
    except: return 0

def pm2_online():
    r = sh("pm2 jlist")
    try:
        return sum(1 for p in json.loads(r.stdout) if p["pm2_env"]["status"]=="online")
    except: return 0

def clean_logs():
    cutoff = time.time() - CFG["log_keep_days"]*86400
    n = 0; freed = 0
    for f in (CYBRA/"logs").glob("*.log*"):
        try:
            st = f.stat()
            if st.st_mtime < cutoff:
                freed += st.st_size; f.unlink(); n += 1
        except: pass
    return n, freed

def clean_tasks():
    cutoff = time.time() - CFG["task_keep_hours"]*3600
    n = 0
    for f in (CYBRA/"parliament_core/tasks").glob("*.json"):
        try:
            if f.stat().st_mtime < cutoff:
                f.unlink(); n += 1
        except: pass
    return n

def trim_failed():
    r = sh("redis-cli llen cybra:parliament:failed")
    try: n = int(r.stdout.strip())
    except: return 0
    if n <= CFG["failed_keep"]: return 0
    keep = n - CFG["failed_keep"]
    sh(f"redis-cli ltrim cybra:parliament:failed 0 {CFG['failed_keep']-1}")
    return keep

def check_writers_alive():
    r = sh("pm2 jlist")
    try:
        procs = json.loads(r.stdout)
    except: return {"ok": False, "reason": "pm2 unreadable"}
    needed = ["parliament","menu-worker","menu-autorobot","cybra-evo-ctrl","redis"]
    down = [p for p in needed
            if not any(x["name"]==p and x["pm2_env"]["status"]=="online" for x in procs)]
    if down:
        log(f"  ❌ down: {down}, resurrecting…")
        sh("pm2 restart " + " ".join(down))
        return {"ok": False, "down": down}
    return {"ok": True, "down": []}

def redis_persist():
    """Перевірити що Redis зберігає дані."""
    sh("redis-cli config set save '900 1 300 10 60 10000'")
    r = sh("redis-cli config get save")
    return r.stdout.strip() if r else "?"

def snapshot_state():
    """Снапшот критичних файлів раз на 24 год."""
    snp = CYBRA / "state/snapshots"
    snp.mkdir(parents=True, exist_ok=True)
    today = datetime.now().strftime("%Y%m%d")
    tgt = snp / f"state_{today}.tar.gz"
    if tgt.exists(): return None
    sh(f"tar -czf {tgt} -C {CYBRA} state/evo_baseline.json state/menu_autorobot.json parliament_core/registry.json 2>/dev/null")
    # keep only 7
    for old in sorted(snp.glob("state_*.tar.gz"))[:-7]:
        old.unlink()
    return tgt.name

def cycle():
    t0 = time.time()
    log("═══ AUTOPILOT CYCLE ═══")
    ram = ram_pct(); disk = disk_mb(); online = pm2_online()

    # 1. RAM guard
    if ram >= CFG["ram_critical"]:
        log(f"  🚨 RAM {ram}% CRITICAL — stop non-essential")
        sh("pm2 stop menu-autorobot cybra-evo-ctrl")
    elif ram >= CFG["ram_pause"]:
        log(f"  ⚠️ RAM {ram}% high — pause autorobot")
        sh("pm2 stop menu-autorobot")
    elif ram < CFG["ram_pause"] - 5:
        # restart paused
        for p in ["menu-autorobot","cybra-evo-ctrl"]:
            r = sh(f"pm2 describe {p}")
            if r and "stopped" in r.stdout:
                sh(f"pm2 restart {p}")
                log(f"  ✅ resumed {p}")

    # 2. Disk guard
    if disk < CFG["disk_min_mb"]:
        log(f"  🚨 disk {disk}MB LOW — cleaning")
        sh("redis-cli bgsave")
        sh("pm2 flush 2>/dev/null")

    # 3. Process check
    check_writers_alive()

    # 4. Cleanup
    nl, nfreed = clean_logs()
    nt = clean_tasks()
    if nl or nt: log(f"  🧹 logs: -{nl} ({nfreed//1024}KB)  tasks: -{nt}")
    tf = trim_failed()
    if tf: log(f"  🧹 failed queue: trimmed {tf}")

    # 5. Redis persistence
    redis_persist()

    # 6. Daily snapshot
    snp = snapshot_state()
    if snp: log(f"  📦 snapshot: {snp}")

    # 7. State file
    STATE.write_text(json.dumps({
        "ts": datetime.now(timezone.utc).isoformat(),
        "cycle_sec": round(time.time()-t0, 1),
        "ram": ram, "disk_mb": disk, "pm2_online": online,
    }, indent=2))
    log(f"  ✅ done: {round(time.time()-t0,1)}s  RAM={ram}% disk={disk}MB pm2={online}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "loop":
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else CFG["interval"]
        log(f"═══ AUTOPILOT LOOP (interval={interval}s) ═══")
        while True:
            try: cycle()
            except Exception as e: log(f"ERR {e}")
            time.sleep(interval)
    elif len(sys.argv) > 1 and sys.argv[1] == "once":
        cycle()
    else:
        print("usage: once | loop [sec]")
