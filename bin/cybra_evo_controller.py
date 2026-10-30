#!/usr/bin/env python3
"""CYBRA EVO — bulletproof. Ніколи не падає."""
import os, sys, json, time, signal, subprocess, logging, traceback
from pathlib import Path

HOME = Path(os.path.expanduser("~"))
PM2_HOME = Path(os.environ.get("PM2_HOME", HOME / ".pm2"))
CTL = PM2_HOME / "ctl"
STOPPED = CTL / "stopped"
CRASHES = CTL / "crashes"
LOG = PM2_HOME / "logs" / "evo-ctrl.log"
for d in (STOPPED, CRASHES, LOG.parent):
    try: d.mkdir(parents=True, exist_ok=True)
    except Exception: pass

try:
    logging.basicConfig(level=logging.INFO,
        format="[%(asctime)s] %(levelname)s %(message)s",
        handlers=[logging.FileHandler(LOG), logging.StreamHandler(sys.stdout)])
    log = logging.getLogger("evo")
except Exception:
    log = logging.getLogger("evo"); log.addHandler(logging.NullHandler())

PROTECT = {"cybra-oracle-ctrl","cybra-resurrection-ctrl","cybra-evolution-ctrl",
           "cybra-neuro-ctrl","cybra-evo-ctrl","parliament","redis","cybra-hotreload"}
TICK = 30
RATE_WINDOW = 600
MAX_RESTARTS = 5

def jlist():
    try:
        return json.loads(subprocess.check_output(
            ["pm2","jlist"], stderr=subprocess.DEVNULL, timeout=15) or b"[]")
    except Exception: return []

def pm2(*a):
    try:
        subprocess.run(["pm2",*a], check=False, timeout=30,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception: pass

def is_stopped(n):
    try: return (STOPPED/n).exists()
    except Exception: return False

def note_crash(n):
    try:
        f = CRASHES/n; now = time.time()
        d = []
        if f.exists():
            try: d = json.loads(f.read_text())
            except Exception: d = []
        d = [t for t in d if now-t < RATE_WINDOW]
        d.append(now); f.write_text(json.dumps(d))
        return len(d)
    except Exception: return 0

def reset_crash(n):
    try: (CRASHES/n).unlink(missing_ok=True)
    except Exception: pass

def heal():
    for a in jlist():
        n = a.get("name"); 
        if not n: continue
        if is_stopped(n): continue
        st = a.get("pm2_env",{}).get("status","?")
        if st == "online": reset_crash(n); continue
        if n in PROTECT and st != "errored": continue
        c = note_crash(n)
        if c > MAX_RESTARTS:
            log.warning("%s crash loop (%d) — skip", n, c); continue
        log.info("%s %s → restart (%d/%d)", n, st, c, MAX_RESTARTS)
        pm2("restart", n)

def daemon():
    log.info("EVO start pid=%d", os.getpid())
    stop = {"f": False}
    def sig(s,f):
        log.info("signal %s", s); stop["f"] = True
    for s in (signal.SIGTERM, signal.SIGINT):
        try: signal.signal(s, sig)
        except Exception: pass
    err = 0
    while not stop["f"]:
        try: heal(); err = 0
        except Exception:
            err += 1
            try: log.error("heal err #%d:\n%s", err, traceback.format_exc())
            except Exception: pass
            if err >= 5:
                for _ in range(300):
                    if stop["f"]: break
                    time.sleep(1)
                err = 0; continue
        for _ in range(TICK):
            if stop["f"]: break
            try: time.sleep(1)
            except Exception: stop["f"] = True


# ─── binmix (перенесено з окремого модуля) ───
def binmix_status():
    """Стан бінарних міксерів / binmix процесів."""
    try:
        jl = jlist()
        mixers = [a for a in jl if "binmix" in a.get("name","").lower()]
        return {"count": len(mixers), "processes": [{"name": a["name"], "status": a.get("pm2_env",{}).get("status")} for a in mixers]}
    except Exception as e:
        return {"error": str(e)}

def binmix_mix():
    """Запускає/перезапускає всі binmix-процеси."""
    try:
        jl = jlist()
        acted = []
        for a in jl:
            n = a.get("name","")
            if "binmix" not in n.lower(): continue
            st = a.get("pm2_env",{}).get("status")
            if st != "online":
                pm2("restart", n)
                acted.append(n)
        return {"acted": acted}
    except Exception as e:
        return {"error": str(e)}

def binmix_pack(target_dir=None):
    """Пакує ~/CYBRA/bin + конфіги в tar.gz (заміна binmix-pack)."""
    import tarfile, time
    from datetime import datetime, timezone
    target = Path(target_dir) if target_dir else (HOME/"CYBRA"/"packages")
    target.mkdir(parents=True, exist_ok=True)
    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    out = target/f"cybra-binmix-{ts}.tar.gz"
    with tarfile.open(out, "w:gz") as t:
        t.add(HOME/"CYBRA"/"bin", arcname="bin")
        if (PM2_HOME/"ctl").exists():
            t.add(PM2_HOME/"ctl", arcname="ctl", filter=lambda x: None if x.name.endswith((".token",".sha256","bio-session")) else x)
    return {"archive": str(out), "size_kb": out.stat().st_size//1024}


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv)>1 else "status"
    try:
        if cmd == "daemon": daemon()
        elif cmd == "once":
            try: heal()
            except Exception: log.error(traceback.format_exc())
        elif cmd == "binmix":
            sub = sys.argv[2] if len(sys.argv)>2 else "status"
            if sub == "status": print(json.dumps(binmix_status(), indent=2))
            elif sub == "mix": print(json.dumps(binmix_mix(), indent=2))
            elif sub == "pack": print(json.dumps(binmix_pack(sys.argv[3] if len(sys.argv)>3 else None), indent=2))
            else: print("cmds: binmix status|mix|pack")
        elif cmd == "status":
            for a in jlist():
                n = a.get("name",""); env = a.get("pm2_env",{})
                note = "STOPPED" if is_stopped(n) else ""
                print(f"  {n:30} {env.get('status','?'):10} {env.get('restart_time',0):>8} {note}")
    except (KeyboardInterrupt, SystemExit): pass
    except Exception:
        try: log.error("fatal:\n%s", traceback.format_exc())
        except Exception: pass
        sys.exit(1)
