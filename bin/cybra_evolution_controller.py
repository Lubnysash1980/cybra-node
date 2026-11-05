#!/usr/bin/env python3
"""CYBRA Evolution Controller.

Міряє систему за 8 метриками → рахує % готовності → ліквідує розриви
безпечно → пише звіт парламенту. Ніколи не робить kill, лише pm2 start/restart/save.
"""
import os, sys, json, time, signal, subprocess, logging, hashlib, shutil
from pathlib import Path
from datetime import datetime, timezone

HOME     = Path(os.path.expanduser("~"))
PM2_HOME = Path(os.environ.get("PM2_HOME", HOME / ".pm2"))
CTL      = PM2_HOME / "ctl"
LOGDIR   = PM2_HOME / "logs"
EVO      = PM2_HOME / "evolution"
HIST     = EVO / "history"
QUEUE    = HOME / "CYBRA" / "queue" / "parliament"
BIN      = HOME / "CYBRA" / "bin"
for d in (CTL, LOGDIR, EVO, HIST, QUEUE, BIN):
    d.mkdir(parents=True, exist_ok=True)

LOG = LOGDIR / "evolution-ctrl.log"
logging.basicConfig(level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG), logging.StreamHandler(sys.stdout)])
log = logging.getLogger("evo2")

STATE_FILE = EVO / "state.json"
SCORE_FILE = EVO / "score.json"
CFG_FILE   = CTL / "evolution.conf.json"

DEFAULT_CFG = {
    "tick_sec": 60,
    "protect": ["cybra-oracle-ctrl", "cybra-resurrection-ctrl", "cybra-evolution-ctrl", "cybra-neuro-ctrl", "cybra-evo-ctrl", "parliament", "redis"],
    "target_score": 100,
    "min_score": 60,
    "metrics": {
        "pm2_online":          {"weight": 20},
        "controllers_alive":   {"weight": 15},
        "parliament_online":   {"weight": 10},
        "watchdog_cron":       {"weight": 10},
        "token_gate":          {"weight": 10},
        "dump_saved":          {"weight": 10},
        "modules_present":     {"weight": 15},
        "no_crash_storm":      {"weight": 10}
    }
}

def cfg():
    if CFG_FILE.exists():
        try: c = json.loads(CFG_FILE.read_text()); b = dict(DEFAULT_CFG); b.update(c); return b
        except Exception: pass
    CFG_FILE.write_text(json.dumps(DEFAULT_CFG, indent=2)); return DEFAULT_CFG

def pm2(*a, timeout=30):
    try: subprocess.run(["pm2", *a], check=False, timeout=timeout,
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); return True
    except Exception: return False

def jlist():
    try:
        out = subprocess.check_output(["pm2", "jlist"], stderr=subprocess.DEVNULL, timeout=15)
        return json.loads(out or b"[]")
    except Exception: return []

def snapshot():
    m = {}
    for a in jlist():
        n = a.get("name"); 
        if not n: continue
        env = a.get("pm2_env", {})
        m[n] = {"status": env.get("status","?"), "restarts": env.get("restart_time",0),
                "mem_mb": env.get("monit",{}).get("memory",0)//(1024*1024)}
    return m

def ram():
    try:
        info = {}
        for l in open("/proc/meminfo"):
            k,v = l.split(":",1); info[k.strip()] = int(v.strip().split()[0])
        t = info.get("MemTotal",0); a = info.get("MemAvailable",0)
        return round((t-a)/1024,1), round(t/1024,1)
    except Exception: return 0.0, 0.0

def is_user_stopped(n): return (CTL/"stopped"/n).exists()
def is_protected(n):    return (CTL/"protected"/f"{n}.json").exists()

# ---------- metrics ----------
def m_pm2_online(snap, c):
    if not snap: return 0, "pm2 empty"
    core = set(c["protect"])
    ok, total = 0, 0
    for n, d in snap.items():
        if n in core:
            total += 1; ok += 1 if d["status"] == "online" else 0
        elif is_user_stopped(n):
            continue  # не рахуємо
        else:
            total += 1; ok += 1 if d["status"] == "online" else 0
    pct = round(ok*100/total,1) if total else 0
    return pct, f"{ok}/{total} online (core+active)"

def m_controllers_alive(snap, c):
    need = ["cybra-neuro-ctrl","cybra-evo-ctrl","cybra-evolution-ctrl"]
    ok = sum(1 for n in need if n in snap and snap[n]["status"]=="online")
    return round(ok*100/len(need),1), f"{ok}/{len(need)} controllers"

def m_parliament_online(snap, c):
    d = snap.get("parliament")
    return (100 if d and d["status"]=="online" else 0), ("online" if d else "missing")

def m_watchdog_cron(snap, c):
    try:
        out = subprocess.check_output(["crontab","-l"], stderr=subprocess.DEVNULL, timeout=10).decode()
        ok = "guard-watchdog.sh" in out
        return (100 if ok else 0), ("cron ok" if ok else "cron missing")
    except Exception:
        return 0, "crontab unavailable"

def m_token_gate(snap, c):
    g = HOME/"bin"/"cybra-guard"
    if not g.exists(): return 0, "gate binary missing"
    try:
        r = subprocess.run([str(g),"stop","__evolution_probe__"],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=10, check=False)
        out = r.stdout.decode(errors="ignore")
        if "DENY" in out:
            return 100, "blocks"
        return 0, f"does not block (rc={r.returncode})"
    except Exception as e:
        return 0, f"gate error: {e}"

def m_dump_saved(snap, c):
    return (100 if (PM2_HOME/"dump.pm2").exists() else 0), ("dump ok" if (PM2_HOME/"dump.pm2").exists() else "dump missing")

def m_modules_present(snap, c):
    need = ["parliament","evolution","guardian","autosave","snapshot","neuro","evo"]
    have = 0
    for n in need:
        if any(BIN.glob(f"*{n}*")) or (HOME/"bin"/n).exists():
            have += 1
    return round(have*100/len(need),1), f"{have}/{len(need)} modules"

def m_no_crash_storm(snap, c):
    hot = [n for n,d in snap.items() if d["restarts"] >= 5 and d["status"]!="online"]
    if not hot: return 100, "no crash storm"
    return 0, f"crash storm: {hot}"

METRIC_FN = {
    "pm2_online": m_pm2_online, "controllers_alive": m_controllers_alive,
    "parliament_online": m_parliament_online, "watchdog_cron": m_watchdog_cron,
    "token_gate": m_token_gate, "dump_saved": m_dump_saved,
    "modules_present": m_modules_present, "no_crash_storm": m_no_crash_storm,
}

# ---------- heal steps for gaps ----------
def heal_pm2(c, snap):
    rm = CTL/"stopped"
    for n in c["protect"]:
        if n in snap and snap[n]["status"]!="online":
            log.info("HEAL pm2 start %s", n); pm2("start", n)
    for n,d in snap.items():
        if n in c["protect"] or is_user_stopped(n): continue
        if d["status"]!="online":
            log.info("HEAL pm2 restart %s", n); pm2("restart", n)

def heal_controllers(c, snap):
    if "cybra-neuro-ctrl" not in snap:
        pm2("start", str(BIN/"cybra_neuro_controller.py"),
            "--name","cybra-neuro-ctrl","--interpreter","python3","--","daemon")
    if "cybra-evo-ctrl" not in snap:
        pm2("start", str(BIN/"cybra_evo_controller.py"),
            "--name","cybra-evo-ctrl","--interpreter","python3","--","daemon")

def heal_watchdog(c, snap):
    try:
        cur = subprocess.check_output(["crontab","-l"], stderr=subprocess.DEVNULL, timeout=10).decode()
    except Exception:
        cur = ""
    if "guard-watchdog.sh" not in cur:
        line = f"* * * * * {HOME}/bin/guard-watchdog.sh >/dev/null 2>&1"
        new  = (cur.rstrip() + "\n" + line + "\n").lstrip()
        subprocess.run(["crontab","-"], input=new.encode(), check=False, timeout=15)
        log.info("HEAL watchdog cron added")

def heal_parliament(c, snap):
    if "parliament" not in snap:
        pm2("start", "parliament")

def heal_dump(c, snap):
    # безпечний save: тільки якщо реально багато online
    try:
        import subprocess
        jl = json.loads(subprocess.check_output(["pm2","jlist"], stderr=subprocess.DEVNULL, timeout=10) or b"[]")
        online = sum(1 for a in jl if a.get("pm2_env",{}).get("status")=="online")
        if online >= 20:
            pm2("save")
    except Exception:
        pass

HEAL_FN = {
    "pm2_online": heal_pm2, "controllers_alive": heal_controllers,
    "watchdog_cron": heal_watchdog, "parliament_online": heal_parliament,
    "dump_saved": heal_dump,
}

def compute(c, snap):
    metrics = {}
    total_w = 0; weighted = 0
    for name, spec in c["metrics"].items():
        w = spec["weight"]; total_w += w
        fn = METRIC_FN[name]
        try: pct, note = fn(snap, c)
        except Exception as e: pct, note = 0, f"error {e}"
        metrics[name] = {"pct": pct, "weight": w, "note": note}
        weighted += pct * w / 100
    score = round(weighted*100/total_w, 1) if total_w else 0
    return score, metrics

HASH_SEAL_HOOK = True
def hash_seal_if_100(score):
    if score < 100.0: return None
    try:
        import subprocess
        r = subprocess.run(["python3", str(HOME/"CYBRA"/"bin"/"cybra_hash_ecosystem.py"), "seal", "evolution-100pct"],
                           capture_output=True, timeout=20)
        return r.stdout.decode(errors="ignore").strip()
    except Exception: return None

def write_score(score, metrics, healing):
    payload = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "score_pct": score,
        "metrics": metrics,
        "healing": healing,
        "ram_mb": dict(zip(("used","total"), ram())),
    }
    SCORE_FILE.write_text(json.dumps(payload, indent=2))
    (HIST / f"score-{int(time.time())}.json").write_text(json.dumps(payload, indent=2))
    # обмежуємо історію
    files = sorted(HIST.glob("score-*.json"))
    for old in files[:-200]: old.unlink(missing_ok=True)

def report_to_parliament(kind, payload):
    ts = int(time.time())
    f = QUEUE / f"report-evo-{kind}-{ts}.json"
    body = {"id": f"report-evo-{kind}-{ts}", "from": "cybra-evolution-ctrl",
            "to": "parliament", "kind": kind,
            "ts": datetime.now(timezone.utc).isoformat(),
            "payload": payload,
            "hash": hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()}
    tmp = f.with_suffix(".tmp"); tmp.write_text(json.dumps(body, indent=2)); tmp.rename(f)

def tick():
    c = cfg(); snap = snapshot()
    score, metrics = compute(c, snap)
    healing = []
    # ліквідація розривів, спершу критичні
    order = sorted(c["metrics"].items(), key=lambda kv: -kv[1]["weight"])
    for name, _spec in order:
        if name in HEAL_FN and metrics[name]["pct"] < 100:
            before = metrics[name]["pct"]
            log.info("HEAL %s (%s%%) → %s", name, before, metrics[name]["note"])
            try: HEAL_FN[name](c, snap)
            except Exception as e: log.exception("heal %s failed: %s", name, e)
            healing.append(name)
    if healing:
        time.sleep(2); snap = snapshot()
        score, metrics = compute(c, snap)
    write_score(score, metrics, healing)
    if score >= 100.0:
        try:
            import subprocess as _sp
            _sp.run([str(HOME/"bin"/"snap-auto.sh"), "evo-100", "--force"],
                    timeout=60, check=False, stdout=_sp.DEVNULL, stderr=_sp.DEVNULL)
        except Exception: pass
        r = hash_seal_if_100(score)
        if r: log.info("HASH SEAL: %s", r)
    log.info("SCORE %s%% (%s)", score, ", ".join(f"{k}={v['pct']}" for k,v in metrics.items()))
    report_to_parliament("score", {"score_pct": score, "metrics": metrics, "healing": healing})
    if score < c["min_score"]:
        report_to_parliament("alert", {"score_pct": score, "min": c["min_score"], "metrics": metrics})
        log.warning("SCORE BELOW MIN %s < %s", score, c["min_score"])

def daemon():
    log.info("EVOLUTION CONTROLLER start")
    stop = {"f": False}
    def sig(s, f): log.info("signal %s", s); stop["f"] = True
    signal.signal(signal.SIGTERM, sig); signal.signal(signal.SIGINT, sig)
    while not stop["f"]:
        try: tick()
        except Exception as e: log.exception("tick: %s", e)
        for _ in range(cfg()["tick_sec"]):
            if stop["f"]: break
            time.sleep(1)
    log.info("EVOLUTION stopped")

def status():
    c = cfg(); snap = snapshot()
    score, metrics = compute(c, snap)
    print(f"SCORE      : {score}%   (target {c['target_score']}%, min {c['min_score']}%)")
    print(f"RAM        : {ram()[0]} / {ram()[1]} MB")
    print(f"{'metric':22} {'pct':>6}  {'weight':>6}  note")
    for k, v in metrics.items():
        print(f"{k:22} {v['pct']:>6}  {v['weight']:>6}  {v['note']}")
    print(f"protected  : {c['protect']}")

def main():
    a = sys.argv[1] if len(sys.argv) > 1 else "status"
    if   a == "status": status()
    elif a == "once":   tick(); status()
    elif a == "daemon": daemon()
    elif a == "score":
        if SCORE_FILE.exists(): print(SCORE_FILE.read_text())
        else: print("no score yet")
    elif a == "protect":
        c = cfg()
        if len(sys.argv) > 2 and sys.argv[2] not in c["protect"]:
            c["protect"].append(sys.argv[2]); CFG_FILE.write_text(json.dumps(c, indent=2))
        print(c["protect"])
    else:
        print("commands: status | once | daemon | score | protect <name>")

if __name__ == "__main__":
    main()
