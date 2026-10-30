#!/usr/bin/env python3
"""CYBRA Neuro Main Controller.

Єдиний мозок над PM2. Не вбиває, не перезаписує — лише безпечні stop/start.
Співпрацює з парламентом через файлову чергу.
"""
import os, sys, json, time, signal, subprocess, logging, shutil, hashlib
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.path.expanduser("~"))
PM2_HOME = Path(os.environ.get("PM2_HOME", HOME / ".pm2"))
CTL = PM2_HOME / "ctl"
LOG_DIR = PM2_HOME / "logs"
QUEUE = HOME / "CYBRA" / "queue" / "parliament"
STATE = CTL / "neuro-state.json"
CFG   = CTL / "neuro.conf.json"
for d in (CTL, LOG_DIR, QUEUE):
    d.mkdir(parents=True, exist_ok=True)

LOG = LOG_DIR / "neuro-ctrl.log"
logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG), logging.StreamHandler(sys.stdout)],
)
log = logging.getLogger("neuro")

DEFAULT_CFG = {
    "ram_threshold_mb": 500,       # якщо > цього → throttle
    "ram_resume_mb": 400,          # якщо < цього → resume
    "tick_sec": 15,
    "protect": ["cybra-oracle-ctrl", "cybra-resurrection-ctrl",                    # ніколи не чіпати
        "cybra-neuro-ctrl",
        "cybra-evo-ctrl",
        "parliament",
        "redis"
    ],
    "priority": {                  # 3=core, 2=important, 1=worker, 0=optional
        "cybra-neuro-ctrl": 3, "cybra-evo-ctrl": 3, "parliament": 3, "redis": 3,
        "cybra-api": 2, "cybra-token-guard": 2, "cybra-git-sync": 2,
        "cybra-sync-a": 1, "cybra-sync-b": 1, "cybra-sync-c": 1,
        "hidl-worker": 2, "hidl-notifier": 1,
        "menu-worker": 1, "menu-autorobot": 1, "taxi-events": 1,
        "cybra-ai-a": 1, "cybra-ai-b": 1, "cybra-ai-100pct": 1,
        "cybra-autopatch": 1, "cybra-autopilot": 1,
        "cybra-binmix-mixin": 1, "cybra-complexity": 0
    },
    "throttle_order": [0, 1, 2],  # спершу optional (0), потім worker (1), потім important (2)
}

def load_cfg():
    if CFG.exists():
        try:
            c = json.loads(CFG.read_text())
            base = dict(DEFAULT_CFG); base.update(c); return base
        except Exception:
            pass
    CFG.write_text(json.dumps(DEFAULT_CFG, indent=2))
    return DEFAULT_CFG

def pm2_jlist():
    try:
        out = subprocess.check_output(["pm2", "jlist"], stderr=subprocess.DEVNULL, timeout=15)
        return json.loads(out or b"[]")
    except Exception:
        return []

def pm2(*args, timeout=30):
    try:
        subprocess.run(["pm2", *args], check=False, timeout=timeout,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception:
        return False

def ram_used_mb():
    try:
        with open("/proc/meminfo") as f:
            lines = f.read().splitlines()
        info = {}
        for l in lines:
            k, v = l.split(":", 1)
            info[k.strip()] = int(v.strip().split()[0])  # KB
        total = info.get("MemTotal", 0)
        avail = info.get("MemAvailable", 0)
        return round((total - avail) / 1024, 1), round(total / 1024, 1)
    except Exception:
        return 0.0, 0.0

def state_load():
    if STATE.exists():
        try: return json.loads(STATE.read_text())
        except Exception: pass
    return {"throttled": False, "throttled_at": None, "last_change": None}

def state_save(s):
    STATE.write_text(json.dumps(s, indent=2))

def is_stopped_by_user(name):
    return (CTL / "stopped" / name).exists()

def app_status_map():
    m = {}
    for a in pm2_jlist():
        n = a.get("name"); 
        if not n: continue
        env = a.get("pm2_env", {})
        m[n] = {
            "status": env.get("status", "?"),
            "restarts": env.get("restart_time", 0),
            "mem": env.get("monit", {}).get("memory", 0) // (1024*1024),
        }
    return m

def report_to_parliament(kind, payload):
    """Пише звіт у чергу парламенту. Парламент — єдиний, хто може його прочитати й діяти."""
    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    f = QUEUE / f"report-{kind}-{ts}.json"
    body = {
        "id": f"report-{kind}-{ts}",
        "from": "cybra-neuro-ctrl",
        "to": "parliament",
        "kind": kind,
        "ts": datetime.now(timezone.utc).isoformat(),
        "payload": payload,
        "hash": hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest(),
    }
    tmp = f.with_suffix(".tmp")
    tmp.write_text(json.dumps(body, indent=2))
    tmp.rename(f)

def throttle(cfg, state, used, total):
    """Безпечне вивільнення RAM: stop optional → worker → important. Ніколи не kill."""
    order = cfg["throttle_order"]
    stopped = []
    status = app_status_map()
    for lvl in order:
        # найбільші спершу в межах рівня
        candidates = sorted(
            [(n, d) for n, d in status.items()
             if cfg["priority"].get(n, 1) == lvl
             and n not in cfg["protect"]
             and d["status"] == "online"
             and not is_stopped_by_user(n)],
            key=lambda x: -x[1]["mem"]
        )
        for n, d in candidates:
            log.info("THROTTLE stop %s (prio=%s, mem=%sMB) RAM=%s/%s", n, lvl, d["mem"], used, total)
            pm2("stop", n)
            stopped.append(n)
            used, _ = ram_used_mb()
            if used < cfg["ram_resume_mb"]:
                log.info("RAM down to %sMB → достатньо, стоп throttle", used)
                state["throttled"] = True
                state["throttled_at"] = datetime.now(timezone.utc).isoformat()
                state["last_change"] = datetime.now(timezone.utc).isoformat()
                state["stopped_by_throttle"] = stopped
                state_save(state)
                report_to_parliament("throttle", {
                    "used_mb": used, "total_mb": total,
                    "stopped": stopped, "level_reached": lvl,
                    "resume_threshold_mb": cfg["ram_resume_mb"]
                })
                return True
    # не вистачило — дійшли до important, лог
    state["throttled"] = True
    state["throttled_at"] = datetime.now(timezone.utc).isoformat()
    state["stopped_by_throttle"] = stopped
    state_save(state)
    report_to_parliament("throttle_exhausted", {
        "used_mb": used, "total_mb": total, "stopped": stopped
    })
    log.warning("THROTTLE EXHAUSTED — RAM все ще %sMB, усі non-core зупинені", used)
    return False

def resume(cfg, state):
    """Підняти назад те, що зупинив throttle. Не чіпати те, що юзер стопнув."""
    stopped = state.get("stopped_by_throttle", [])
    for n in stopped:
        if is_stopped_by_user(n):
            continue
        log.info("RESUME start %s", n)
        pm2("start", n)
    state["throttled"] = False
    state["stopped_by_throttle"] = []
    state["last_change"] = datetime.now(timezone.utc).isoformat()
    state_save(state)
    used, total = ram_used_mb()
    report_to_parliament("resume", {
        "used_mb": used, "total_mb": total, "started": stopped
    })

def tick():
    cfg = load_cfg()
    state = state_load()
    used, total = ram_used_mb()
    if total <= 0:
        log.warning("ram unknown"); return
    pct = round(used / total * 100, 1)
    log.info("RAM %s/%sMB (%s%%) throttled=%s", used, total, pct, state.get("throttled", False))

    if not state.get("throttled", False) and used >= cfg["ram_threshold_mb"]:
        log.info("RAM %sMB ≥ %sMB → THROTTLE", used, cfg["ram_threshold_mb"])
        throttle(cfg, state, used, total)
    elif state.get("throttled", False) and used <= cfg["ram_resume_mb"]:
        log.info("RAM %sMB ≤ %sMB → RESUME", used, cfg["ram_resume_mb"])
        resume(cfg, state)

def daemon():
    log.info("NEURO MAIN CONTROLLER start")
    stop = {"flag": False}
    def sig(s, f):
        log.info("signal %s → stop", s); stop["flag"] = True
    signal.signal(signal.SIGTERM, sig); signal.signal(signal.SIGINT, sig)
    while not stop["flag"]:
        try: tick()
        except Exception as e:
            log.exception("tick error: %s", e)
        cfg = load_cfg()
        for _ in range(cfg["tick_sec"]):
            if stop["flag"]: break
            time.sleep(1)
    log.info("NEURO stopped")

def cmd_status():
    cfg = load_cfg(); state = state_load()
    used, total = ram_used_mb()
    print(f"RAM        : {used} / {total} MB ({round(used/total*100,1) if total else 0}%)")
    print(f"threshold  : {cfg['ram_threshold_mb']} MB, resume at {cfg['ram_resume_mb']} MB")
    print(f"throttled  : {state.get('throttled', False)}")
    print(f"stopped    : {state.get('stopped_by_throttle', [])}")
    print(f"protected  : {cfg['protect']}")
    print()
    print(f"{'name':30} {'status':10} {'mem':>6} {'prio':>5}  note")
    for n, d in sorted(app_status_map().items()):
        note = "PROTECTED" if n in cfg["protect"] else ""
        print(f"{n:30} {d['status']:10} {d['mem']:>5}M {cfg['priority'].get(n,1):>5}  {note}")

def cmd_once():
    tick()
    cmd_status()

def main():
    c = sys.argv[1] if len(sys.argv) > 1 else "status"
    if   c == "status": cmd_status()
    elif c == "once":   cmd_once()
    elif c == "daemon": daemon()
    elif c == "threshold":
        cfg = load_cfg()
        if len(sys.argv) > 2: cfg["ram_threshold_mb"] = int(sys.argv[2])
        if len(sys.argv) > 3: cfg["ram_resume_mb"] = int(sys.argv[3])
        CFG.write_text(json.dumps(cfg, indent=2))
        print(json.dumps(cfg, indent=2))
    elif c == "protect":
        cfg = load_cfg()
        if len(sys.argv) > 2:
            name = sys.argv[2]
            if name not in cfg["protect"]: cfg["protect"].append(name)
            CFG.write_text(json.dumps(cfg, indent=2))
        print("protect:", cfg["protect"])
    else:
        print("commands: status | once | daemon | threshold <hi> [<lo>] | protect [name]")

if __name__ == "__main__":
    main()
