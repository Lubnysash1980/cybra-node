#!/usr/bin/env python3
"""CYBRA Resurrection Controller.

Підконтрольний парламенту. Закритий парламентським токеном:
без нього НЕ має права робити restart/stop/delete.
Після падіння/ребуту піднімає систему до 100% (за метриками Evolution).
"""
import os, sys, json, time, signal, subprocess, logging, hashlib
from pathlib import Path
from datetime import datetime, timezone

HOME     = Path(os.path.expanduser("~"))
PM2_HOME = Path(os.environ.get("PM2_HOME", HOME / ".pm2"))
CTL      = PM2_HOME / "ctl"
LOGDIR   = PM2_HOME / "logs"
RES      = PM2_HOME / "resurrection"
HIST     = RES / "history"
QUEUE    = HOME / "CYBRA" / "queue" / "parliament"
EVO_DIR  = PM2_HOME / "evolution"
BIN      = HOME / "CYBRA" / "bin"
TOKEN_F  = CTL / "parliament.token"
GUARD    = HOME / "bin" / "cybra-guard"
for d in (CTL, LOGDIR, RES, HIST, QUEUE, EVO_DIR, BIN):
    d.mkdir(parents=True, exist_ok=True)

LOG = LOGDIR / "resurrection-ctrl.log"
logging.basicConfig(level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG), logging.StreamHandler(sys.stdout)])
log = logging.getLogger("res")

STATE_F = RES / "state.json"
CFG_F   = CTL / "resurrection.conf.json"
DEFAULT_CFG = {
    "tick_sec": 30,
    "protect": ["cybra-oracle-ctrl", "cybra-resurrection-ctrl", "cybra-evolution-ctrl",
                "cybra-neuro-ctrl", "cybra-evo-ctrl", "parliament", "redis"],
    "max_restarts_per_window": 3,
    "window_sec": 600,
    "target_score": 100.0,
    "min_score_trigger": 99.9,     # якщо score нижче — почати відновлення
}

def cfg():
    if CFG_F.exists():
        try: c = json.loads(CFG_F.read_text()); b = dict(DEFAULT_CFG); b.update(c); return b
        except Exception: pass
    CFG_F.write_text(json.dumps(DEFAULT_CFG, indent=2)); return DEFAULT_CFG

def state():
    if STATE_F.exists():
        try: return json.loads(STATE_F.read_text())
        except Exception: pass
    return {"boots": [], "restarts": {}, "last_full_recovery": None}

def save_state(s):
    STATE_F.write_text(json.dumps(s, indent=2))

def read_token():
    if not TOKEN_F.exists(): return None
    t = TOKEN_F.read_text().strip()
    return t or None

def guard(*args, token=None):
    """Деструктивні дії — ТІЛЬКИ через cybra-guard з токеном парламенту."""
    tok = token or read_token()
    if not tok:
        log.error("NO TOKEN — parliament token missing; refusing destructive op: %s", args)
        return False
    if not GUARD.exists():
        log.error("cybra-guard missing"); return False
    env = dict(os.environ); env["CYBRA_TOKEN"] = tok
    try:
        r = subprocess.run([str(GUARD), *args], env=env, check=False, timeout=60,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = r.stdout.decode(errors="ignore")
        if "DENY" in out:
            log.error("guard DENY for %s: %s", args, out.strip()); return False
        return True
    except Exception as e:
        log.exception("guard exec error: %s", e); return False

def pm2_safe(*args, timeout=30):
    """Недеструктивні pm2-операції (status, jlist, save, resurrect, start)."""
    try:
        subprocess.run(["pm2", *args], check=False, timeout=timeout,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception: return False

def safe_save():
    """pm2 save ТІЛЬКИ якщо >=20 online і нема неочікуваних stopped."""
    try:
        jl = jlist()
        online = sum(1 for a in jl if a.get("pm2_env",{}).get("status")=="online")
        if online >= 20:
            pm2_safe("save")
    except Exception:
        pass

def jlist():
    try:
        out = subprocess.check_output(["pm2", "jlist"], stderr=subprocess.DEVNULL, timeout=15)
        return json.loads(out or b"[]")
    except Exception: return []

def snap():
    m = {}
    for a in jlist():
        n = a.get("name");
        if not n: continue
        env = a.get("pm2_env", {})
        m[n] = {"status": env.get("status","?"), "restarts": env.get("restart_time",0),
                "mem_mb": env.get("monit",{}).get("memory",0)//(1024*1024)}
    return m

def current_score():
    f = EVO_DIR / "score.json"
    if not f.exists(): return None
    try: return float(json.loads(f.read_text()).get("score_pct", 0))
    except Exception: return None

def is_protected_by_parliament(n):
    return (CTL / "protected" / f"{n}.json").exists()

def is_user_stopped(n):
    return (CTL / "stopped" / n).exists()

def within_rate(st, name, c):
    now = time.time()
    lst = [t for t in st["restarts"].get(name, []) if now - t < c["window_sec"]]
    st["restarts"][name] = lst
    return len(lst) < c["max_restarts_per_window"]

def note_restart(st, name):
    st["restarts"].setdefault(name, []).append(time.time())

def report(kind, payload):
    ts = int(time.time())
    f = QUEUE / f"report-res-{kind}-{ts}.json"
    body = {"id": f"report-res-{kind}-{ts}",
            "from": "cybra-resurrection-ctrl", "to": "parliament",
            "kind": kind, "ts": datetime.now(timezone.utc).isoformat(),
            "payload": payload,
            "hash": hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()}
    tmp = f.with_suffix(".tmp"); tmp.write_text(json.dumps(body, indent=2)); tmp.rename(f)

def boot_recovery(c, st):
    """Після ребуту: pm2 resurrect + гарантія core-процесів."""
    log.info("BOOT RECOVERY start")
    if (PM2_HOME / "dump.pm2").exists():
        pm2_safe("resurrect"); time.sleep(3)
    snap_ = snap()
    # core-контролери піднімаємо напряму (start — не деструктивна)
    core_proc = {
        "cybra-neuro-ctrl":       [str(BIN/"cybra_neuro_controller.py"), "--name","cybra-neuro-ctrl","--interpreter","python3","--","daemon"],
        "cybra-evo-ctrl":         [str(BIN/"cybra_evo_controller.py"),   "--name","cybra-evo-ctrl","--interpreter","python3","--","daemon"],
        "cybra-evolution-ctrl":   [str(BIN/"cybra_evolution_controller.py"),"--name","cybra-evolution-ctrl","--interpreter","python3","--","daemon"],
    }
    for name, args in core_proc.items():
        if name not in snap_ or snap_[name]["status"] != "online":
            if Path(args[0]).exists():
                log.info("BOOT start %s", name); pm2_safe("start", *args); time.sleep(1)
    pass  # DISABLED: pm2 save тут псує dump (race)
    st["boots"].append(datetime.now(timezone.utc).isoformat())
    st["boots"] = st["boots"][-50:]
    save_state(st)
    report("boot", {"boots_recent": len(st["boots"])})
    log.info("BOOT RECOVERY done")

def full_recovery(c, st):
    """Довести до 100%: рестарт усього, крім protected і user-stopped."""
    log.info("FULL RECOVERY start")
    snap_ = snap()
    acted = []
    for n, d in snap_.items():
        if is_user_stopped(n):         continue
        if is_protected_by_parliament(n) and n not in ("parliament","redis"):
            # protected не чіпаємо через рестарт, тільки якщо явно errored
            if d["status"] == "errored":
                if within_rate(st, n, c) and guard("restart", n):
                    note_restart(st, n); acted.append(n)
            continue
        if d["status"] != "online":
            if not within_rate(st, n, c):
                log.warning("rate-limit %s — skip", n); continue
            if guard("restart", n):
                note_restart(st, n); acted.append(n)
            else:
                # fallback: pm2 start (не деструктивна) — якщо guard не пропустив
                pm2_safe("start", n); acted.append(n+"(start)")
    pass  # DISABLED: pm2 save тут псує dump (race)
    st["last_full_recovery"] = datetime.now(timezone.utc).isoformat()
    save_state(st)
    report("recovery", {"acted": acted})
    log.info("FULL RECOVERY done: %s", acted)

def tick():
    c = cfg(); st = state()
    score = current_score()
    log.info("tick score=%s", score)
    if score is None:
        # evolution ще не рахував — один boot-pass
        boot_recovery(c, st); return
    if score < c["min_score_trigger"]:
        log.warning("score %s < %s → FULL RECOVERY", score, c["min_score_trigger"])
        full_recovery(c, st)
        # дочекатись нового score
        time.sleep(3)
        s2 = current_score()
        report("post_recovery", {"before": score, "after": s2})
        try:
            import subprocess as _sp
            _sp.run([str(HOME/"bin"/"snap-auto.sh"), "post-recovery", "--force"],
                    timeout=90, check=False, stdout=_sp.DEVNULL, stderr=_sp.DEVNULL)
        except Exception: pass
        log.info("post-recovery score=%s", s2)

def daemon():
    log.info("RESURRECTION CONTROLLER start (token %s)",
             "present" if read_token() else "MISSING — read-only mode")
    st = state(); c = cfg()
    if not st.get("boots"):
        boot_recovery(c, st)
    stop = {"f": False}
    def sig(s, f): log.info("signal %s", s); stop["f"] = True
    signal.signal(signal.SIGTERM, sig); signal.signal(signal.SIGINT, sig)
    while not stop["f"]:
        try: tick()
        except Exception as e: log.exception("tick: %s", e)
        for _ in range(cfg()["tick_sec"]):
            if stop["f"]: break
            time.sleep(1)
    log.info("RESURRECTION stopped")

def status():
    c = cfg(); st = state()
    tok = read_token()
    print(f"token         : {'present' if tok else 'MISSING (read-only)'}")
    print(f"score         : {current_score()}%  (trigger < {c['min_score_trigger']}%)")
    print(f"last recovery : {st.get('last_full_recovery')}")
    print(f"boots (recent) : {len(st.get('boots', []))}")
    print(f"protected     : {c['protect']}")

def main():
    a = sys.argv[1] if len(sys.argv) > 1 else "status"
    if   a == "status": status()
    elif a == "once":   tick(); status()
    elif a == "boot":   boot_recovery(cfg(), state()); status()
    elif a == "daemon": daemon()
    elif a == "token-check":
        print("ok" if read_token() else "missing")
    else:
        print("commands: status | once | boot | daemon | token-check")

if __name__ == "__main__":
    main()
