#!/usr/bin/env python3
"""CYBRA Oracle Predictive Controller.

Дивиться на 7 кроків уперед. Ловить зміни: файли, git, звіти інших
контролерів, чергу парламенту. Будує сценарії. Робить безпечні
попереджувальні дії. Звітує парламенту. Деструктив — лише через токен.
"""
import os, sys, json, time, signal, subprocess, logging, hashlib, re
from pathlib import Path
from datetime import datetime, timezone

HOME     = Path(os.path.expanduser("~"))
PM2_HOME = Path(os.environ.get("PM2_HOME", HOME / ".pm2"))
CTL      = PM2_HOME / "ctl"
LOGDIR   = PM2_HOME / "logs"
ORA      = PM2_HOME / "oracle"
HIST     = ORA / "history"
SIGS     = ORA / "signals"
QUEUE    = HOME / "CYBRA" / "queue" / "parliament"
EVO_DIR  = PM2_HOME / "evolution"
BIN      = HOME / "CYBRA" / "bin"
GUARD    = HOME / "bin" / "cybra-guard"
TOKEN_F  = CTL / "parliament.token"
for d in (CTL, LOGDIR, ORA, HIST, SIGS, QUEUE, EVO_DIR, BIN):
    d.mkdir(parents=True, exist_ok=True)

LOG = LOGDIR / "oracle-ctrl.log"
logging.basicConfig(level=logging.INFO,
    format="[%(asctime)s] %(levelname)s %(message)s",
    handlers=[logging.FileHandler(LOG), logging.StreamHandler(sys.stdout)])
log = logging.getLogger("oracle")

STATE_F = ORA / "state.json"
CFG_F   = CTL / "oracle.conf.json"
HORIZON = 7

DEFAULT_CFG = {
    "tick_sec": 45,
    "horizon": HORIZON,
    "protect": ["cybra-oracle-ctrl", "cybra-resurrection-ctrl", "cybra-evolution-ctrl",
                "cybra-neuro-ctrl", "cybra-evo-ctrl", "parliament", "redis"],
    "watch_paths": ["~/CYBRA", "~/.pm2/ctl", "~/bin"],
    "report_keep": 300,
    "risk_thresholds": {"low": 0.3, "med": 0.6, "high": 0.85},
    "prewarm_modules": ["parliament","evolution","guardian","autosave","snapshot",
                        "neuro","evo","resurrection"],
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
    return {"last_tick": None, "signals": {}, "predictions": [], "actions": []}

def save_state(s): STATE_F.write_text(json.dumps(s, indent=2))

def read_token():
    if not TOKEN_F.exists(): return None
    t = TOKEN_F.read_text().strip(); return t or None

def guard(*args, token=None):
    tok = token or read_token()
    if not tok: log.error("NO TOKEN — refusing destructive: %s", args); return False
    if not GUARD.exists(): log.error("guard missing"); return False
    env = dict(os.environ); env["CYBRA_TOKEN"] = tok
    try:
        r = subprocess.run([str(GUARD), *args], env=env, check=False, timeout=60,
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        out = r.stdout.decode(errors="ignore")
        if "DENY" in out: log.error("guard DENY %s: %s", args, out.strip()); return False
        return True
    except Exception: return False

def pm2_safe(*a, timeout=30):
    try:
        subprocess.run(["pm2", *a], check=False, timeout=timeout,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL); return True
    except Exception: return False

def report(kind, payload):
    ts = int(time.time())
    f = QUEUE / f"report-oracle-{kind}-{ts}.json"
    body = {"id": f"report-oracle-{kind}-{ts}",
            "from": "cybra-oracle-ctrl", "to": "parliament",
            "kind": kind, "ts": datetime.now(timezone.utc).isoformat(),
            "payload": payload,
            "hash": hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest()}
    tmp = f.with_suffix(".tmp"); tmp.write_text(json.dumps(body, indent=2)); tmp.rename(f)
    return f.name

# ---------- SIGNAL COLLECTORS ----------
def sig_files(cfg):
    """Зміни файлів (mtime) у watch_paths."""
    out = {}
    for p in cfg["watch_paths"]:
        base = Path(os.path.expanduser(p))
        if not base.exists(): continue
        for f in base.rglob("*"):
            if not f.is_file(): continue
            if "/.git/" in str(f) or "/node_modules/" in str(f): continue
            try: mt = f.stat().st_mtime
            except Exception: continue
            out[str(f)] = mt
    return out

def sig_git(cfg):
    """Останній коміт / наявність змін у ~/CYBRA."""
    repo = HOME / "CYBRA"
    if not (repo / ".git").exists(): return {}
    try:
        head = subprocess.check_output(["git","-C",str(repo),"rev-parse","HEAD"],
                                       stderr=subprocess.DEVNULL, timeout=10).decode().strip()
        dirty = subprocess.check_output(["git","-C",str(repo),"status","--porcelain"],
                                        stderr=subprocess.DEVNULL, timeout=10).decode()
        return {"head": head, "dirty_count": len(dirty.splitlines())}
    except Exception: return {}

def sig_controllers(cfg):
    """Стан контролерів + звіти, які вони написали парламенту."""
    out = {"alive": [], "missing": [], "recent_reports": []}
    try:
        jl = json.loads(subprocess.check_output(["pm2","jlist"],
            stderr=subprocess.DEVNULL, timeout=15) or b"[]")
    except Exception: jl = []
    online = {a.get("name"): a.get("pm2_env",{}).get("status") for a in jl if a.get("name")}
    need = ["cybra-neuro-ctrl","cybra-evo-ctrl","cybra-evolution-ctrl",
            "cybra-resurrection-ctrl","parliament"]
    for n in need:
        (out["alive"] if online.get(n)=="online" else out["missing"]).append(n)
    # свіжі звіти (за останні 5 хв)
    now = time.time()
    for f in QUEUE.glob("report-*.json"):
        try:
            if now - f.stat().st_mtime < 300:
                out["recent_reports"].append(f.name)
        except Exception: pass
    out["recent_reports"] = out["recent_reports"][-20:]
    return out

def sig_score():
    f = EVO_DIR / "score.json"
    if not f.exists(): return {}
    try: return json.loads(f.read_text())
    except Exception: return {}

def sig_parliament_tasks():
    """Скільки завдань ще не виконано (парламент має чергу)."""
    pend = 0
    for f in QUEUE.glob("task-*.json"):
        try:
            d = json.loads(f.read_text()); i = d.get("id","")
            if i and not (QUEUE / f".done-{i}").exists(): pend += 1
        except Exception: pass
    return {"pending_tasks": pend}

# ---------- PREDICTORS (7 steps) ----------
def predict_files(prev, cur, cfg):
    """Нові/змінені файли → 7-кроковий прогноз ризиків."""
    preds = []
    if not prev: return preds
    new = [f for f in cur if f not in prev]
    mod = [f for f in cur if f in prev and cur[f] > prev[f] + 1]
    for f in new[:20]:
        name = Path(f).name.lower()
        risk = 0.4
        tags = []
        if name.endswith(".py"):
            risk = 0.6; tags.append("new_module")
        if "controller" in name or "ctrl" in name:
            risk = 0.85; tags.append("new_controller")
        if name in ("ecosystem.config.js",) or name.endswith(".conf.json"):
            risk = 0.85; tags.append("config_change")
        if name.endswith(".sh"):
            risk = 0.5; tags.append("script_change")
        preds.append({"step":1, "kind":"file_new", "path":f, "risk":risk, "tags":tags})
    for f in mod[:20]:
        name = Path(f).name.lower()
        risk = 0.5; tags = ["file_modified"]
        if name.endswith(".conf.json") or name == "ecosystem.config.js":
            risk = 0.85; tags.append("config_change")
        preds.append({"step":1, "kind":"file_mod", "path":f, "risk":risk, "tags":tags})
    return preds

def predict_controllers(sig, cfg):
    """Пропали контролери → передбачаємо каскад відмов."""
    preds = []
    for n in sig.get("missing", []):
        # крок 1: впав
        preds.append({"step":1, "kind":"ctrl_down","name":n,"risk":0.9,"tags":["down"]})
        # крок 2-3: залежні теж можуть впасти
        for step, dep in enumerate(["cybra-evolution-ctrl","cybra-resurrection-ctrl"], start=2):
            preds.append({"step":step,"kind":"cascade_risk","name":dep,
                          "cause":n,"risk":0.7,"tags":["cascade"]})
        # крок 4-5: score просів
        preds.append({"step":4,"kind":"score_drop","est_delta":-15,"risk":0.75,"tags":["score"]})
        preds.append({"step":5,"kind":"alert_to_parliament","risk":0.6,"tags":["alert"]})
        # крок 6-7: відновлення
        preds.append({"step":6,"kind":"recovery_boot","risk":0.4,"tags":["recovery"]})
        preds.append({"step":7,"kind":"score_back_100","risk":0.2,"tags":["healthy"]})
    return preds

def predict_score(score, cfg):
    """Прогноз score: якщо < 100 → на 7 кроків падіння."""
    preds = []
    try: s = float(score.get("score_pct", 100))
    except Exception: return preds
    if s < 100:
        for step in range(1, min(cfg["horizon"], 7)+1):
            est = max(0, s - step*2) if s < 50 else max(0, s - step*1)
            risk = 0.6 if s < 80 else 0.4
            preds.append({"step":step, "kind":"score_trend", "est":est,
                          "risk":risk, "tags":["score_trend"]})
    return preds

def predict_tasks(sig, cfg):
    preds = []
    p = sig.get("pending_tasks", 0)
    if p > 0:
        preds.append({"step":1,"kind":"tasks_pending","count":p,"risk":0.3,"tags":["queue"]})
        preds.append({"step":3,"kind":"load_on_parliament","risk":0.4,"tags":["queue"]})
    return preds

# ---------- PRE-EMPTIVE ACTIONS (safe only) ----------
def act_prewarm(cfg, actions):
    """Предзавантажити модулі (import-safe)."""
    for m in cfg["prewarm_modules"]:
        if (BIN / f"cybra_{m}.py").exists() or any(BIN.glob(f"*{m}*")):
            actions.append({"action":"prewarm_ok","module":m})
        # нічого деструктивного, тільки фіксація готовності

def act_dep_check(cfg, actions):
    """Перевірити, що інтерпретатори та залежності доступні."""
    import shutil
    for b in ("python3","pm2","jq","curl"):
        if not shutil.which(b): actions.append({"action":"dep_missing","bin":b,"sev":"high"})
        else: actions.append({"action":"dep_ok","bin":b})

def act_restart_missing(sig, actions):
    """Підняти впалих, АЛЕ через pm2 start (не деструктивно) + токен якщо треба restart."""
    for n in sig.get("missing", []):
        # start — безпечно
        pm2_safe("start", n)
        actions.append({"action":"start_missing","name":n})
        # якщо не піднялось → спробувати через guard restart
        try:
            jl = json.loads(subprocess.check_output(["pm2","jlist"],
                stderr=subprocess.DEVNULL, timeout=10) or b"[]")
            st = next((a.get("pm2_env",{}).get("status") for a in jl if a.get("name")==n), None)
            if st != "online" and guard("restart", n):
                actions.append({"action":"guard_restart","name":n})
        except Exception: pass

def act_write_forecast(state, preds, actions):
    ts = int(time.time())
    payload = {"ts": datetime.now(timezone.utc).isoformat(),
               "horizon": HORIZON, "predictions": preds[-200:], "actions": actions[-100:]}
    (HIST / f"forecast-{ts}.json").write_text(json.dumps(payload, indent=2))
    files = sorted(HIST.glob("forecast-*.json"))
    for old in files[:-300]: old.unlink(missing_ok=True)

# ---------- MAIN TICK ----------
def tick():
    c = cfg(); st = state()
    # 1. signals
    files = sig_files(c)
    s = {
        "files": files,
        "git": sig_git(c),
        "controllers": sig_controllers(c),
        "score": sig_score(),
        "tasks": sig_parliament_tasks(),
    }
    prev_files = st.get("signals", {}).get("files", {})
    # 2. predictions
    preds = []
    preds += predict_files(prev_files, files, c)
    preds += predict_controllers(s["controllers"], c)
    preds += predict_score(s["score"], c)
    preds += predict_tasks(s["tasks"], c)
    high = [p for p in preds if p["risk"] >= c["risk_thresholds"]["high"]]
    # 3. safe pre-emptive actions
    actions = []
    act_dep_check(c, actions)
    act_prewarm(c, actions)
    if s["controllers"].get("missing"):
        act_restart_missing(s["controllers"], actions)
    # 4. persist
    st["last_tick"] = datetime.now(timezone.utc).isoformat()
    st["signals"] = {"files": files, "git": s["git"],
                     "controllers": s["controllers"], "score": s["score"], "tasks": s["tasks"]}
    st["predictions"] = (st.get("predictions", []) + preds)[-500:]
    st["actions"] = (st.get("actions", []) + actions)[-200:]
    save_state(st)
    act_write_forecast(st, preds, actions)
    log.info("tick: signals=%d preds=%d high=%d actions=%d",
             len(files), len(preds), len(high), len(actions))
    # 5. report
    report("forecast", {"horizon": HORIZON,
                        "preds_total": len(preds),
                        "high_risk": high[:20],
                        "actions": actions[-20:]})
    if high:
        report("alert", {"high_risk": high[:20]})

def daemon():
    log.info("ORACLE CONTROLLER start (horizon=%d, token %s)",
             HORIZON, "present" if read_token() else "MISSING (safe mode)")
    stop = {"f": False}
    def sig(s, f): log.info("signal %s", s); stop["f"] = True
    signal.signal(signal.SIGTERM, sig); signal.signal(signal.SIGINT, sig)
    # перший прогін
    try: tick()
    except Exception as e: log.exception("initial tick: %s", e)
    while not stop["f"]:
        for _ in range(cfg()["tick_sec"]):
            if stop["f"]: break
            time.sleep(1)
        try: tick()
        except Exception as e: log.exception("tick: %s", e)
    log.info("ORACLE stopped")

def status():
    c = cfg(); st = state()
    preds = st.get("predictions", [])
    high = [p for p in preds if p.get("risk",0) >= c["risk_thresholds"]["high"]]
    print(f"token         : {'present' if read_token() else 'MISSING (safe mode)'}")
    print(f"horizon       : {HORIZON} steps ahead")
    print(f"last tick     : {st.get('last_tick')}")
    print(f"predictions   : {len(preds)} (high-risk: {len(high)})")
    print(f"actions log   : {len(st.get('actions', []))}")
    print(f"protected     : {c['protect']}")
    if high:
        print("\nHIGH-RISK FORECASTS (next 7 steps):")
        for p in high[:10]:
            print(f"  step {p.get('step','?'):>2}  {p.get('kind'):20}  risk={p.get('risk')}  {p.get('name') or p.get('path') or ''}")

def main():
    a = sys.argv[1] if len(sys.argv) > 1 else "status"
    if   a == "status": status()
    elif a == "once":   tick(); status()
    elif a == "daemon": daemon()
    elif a == "forecast":
        files = sorted(HIST.glob("forecast-*.json"))
        if not files: print("no forecasts yet"); return
        print(files[-1].read_text())
    elif a == "token-check":
        print("ok" if read_token() else "missing")
    else:
        print("commands: status | once | daemon | forecast | token-check")

if __name__ == "__main__":
    main()
