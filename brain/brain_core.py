#!/usr/bin/env python3
import os, sys, json, subprocess, time, re
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
BRAIN = CYBRA / "brain"
STATE_FILE = BRAIN / "state/brain_state.json"
LOG = BRAIN / "logs/brain.log"

# Шляхи до інших систем
SG = CYBRA / "selfgen/selfgen_core.py"
PM = CYBRA / "parliament_core/priority_manager.py"
PARLAMENT = CYBRA / "modules/module_121_parlament/bin/parliament_hidl_engine.py"

def log(msg):
    LOG.parent.mkdir(exist_ok=True)
    with open(LOG, "a") as f:
        f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")
    print(f"  [BRAIN] {msg}")

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

def load_state():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {"cycles": 0, "last_actions": [], "health": 100}

def save_state(state):
    STATE_FILE.parent.mkdir(exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

# ─── 1. ЗБІР МЕТРИК ───
def collect_metrics():
    m = {"pm2": [], "git": "unknown", "modules": 0, "conflicts": 0, "evo_snapshots": 0}
    
    # PM2
    r = run("pm2 jlist")
    if r.returncode == 0:
        try:
            for p in json.loads(r.stdout):
                m["pm2"].append({"name": p["name"], "status": p["pm2_env"]["status"]})
        except: pass

    # Git
    if (CYBRA / ".git").exists():
        r = run("git remote -v", cwd=CYBRA)
        m["git"] = "ok" if "origin" in r.stdout else "no_remote"
    else:
        m["git"] = "no_git"

    # Модулі та конфлікти (з реєстру Парламенту)
    reg_file = CYBRA / "parliament_core/registry.json"
    if reg_file.exists():
        try:
            reg = json.loads(reg_file.read_text())
            m["modules"] = reg.get("total_modules", 0)
            m["conflicts"] = reg.get("conflicts", 0)
        except: pass

    # Снапшоти EVO
    snaps = list((CYBRA / "hashes/snapshots").glob("snapshot_*.json"))
    m["evo_snapshots"] = len(snaps)

    return m

# ─── 2. АНАЛІЗ ТА РІШЕННЯ ───
def decide(metrics):
    actions = []
    
    # Якщо PM2 не всі online — запустити/перезапустити
    offline = [p["name"] for p in metrics["pm2"] if p["status"] != "online"]
    if offline:
        actions.append({"type": "pm2_restart", "target": offline, "reason": "offline processes"})

    # Якщо Git зламався — відновити
    if metrics["git"] != "ok":
        actions.append({"type": "fix_git", "reason": f"git status: {metrics['git']}"})

    # Якщо конфліктів > 20 — запустити clean
    if metrics["conflicts"] > 20:
        actions.append({"type": "parliament_clean", "reason": f"{metrics['conflicts']} conflicts"})

    # Якщо модулів < 100 — запустити генерацію
    if metrics["modules"] < 100:
        actions.append({"type": "parliament_generate", "reason": "too few modules"})

    # Якщо снапшотів < 3 — зробити новий
    if metrics["evo_snapshots"] < 3:
        actions.append({"type": "evo_snapshot", "reason": "few snapshots"})

    return actions

# ─── 3. ВИКОНАННЯ ДІЙ ───
def execute(actions):
    for a in actions:
        log(f"EXEC: {a['type']} (reason: {a.get('reason', '')})")
        if a["type"] == "pm2_restart":
            for n in a["target"]:
                run(f"pm2 restart {n}")
        elif a["type"] == "fix_git":
            run("git remote remove origin", cwd=CYBRA)
            run("git remote add origin https://github.com/Lubnysash1980/cybra-node.git", cwd=CYBRA)
        elif a["type"] == "parliament_clean":
            run(f"python3 {PM} clean")
        elif a["type"] == "parliament_generate":
            run(f"python3 {PARLAMENT} vote")
        elif a["type"] == "evo_snapshot":
            run("~/.termux/boot/start-cybra.sh 2>/dev/null || true")
            run(f"python3 {SG} check")

# ─── 4. ГОЛОВНИЙ ЦИКЛ ───

def auto_commit():
    """Автоматично комітить всі зміни в Git"""
    r = run("git status --porcelain", cwd=CYBRA)
    if r.stdout.strip():
        run("git add -A", cwd=CYBRA)
        run(f"git commit -m 'brain: auto-sync {datetime.now(timezone.utc).isoformat()}'", cwd=CYBRA)
        run("git push origin main", cwd=CYBRA)
        return len(r.stdout.splitlines())
    return 0

def daemon():
    log("Brain started. Monitoring system...")
    state = load_state()
    
    while True:
        state["cycles"] += 1
        
        # Збір метрик
        metrics = collect_metrics()
            committed = auto_commit()
            if committed: log(f'AUTO-COMMIT: {committed} files')
        
        # Аналіз
        actions = decide(metrics)
        
        # Виконання
        if actions:
            execute(actions)
            state["last_actions"] = actions
        else:
            log(f"Cycle {state['cycles']}: all OK (modules={metrics['modules']}, conflicts={metrics['conflicts']})")
            
        # Збереження стану
        save_state(state)
        
        time.sleep(120)  # Мозок думає кожні 2 хвилини

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "daemon":
        daemon()
    else:
        # Режим одноразового аналізу
        m = collect_metrics()
        print(f"PM2: {len([p for p in m['pm2'] if p['status']=='online'])}/{len(m['pm2'])} online")
        print(f"Git: {m['git']}")
        print(f"Modules: {m['modules']}")
        print(f"Conflicts: {m['conflicts']}")
        print(f"Snapshots: {m['evo_snapshots']}")
        actions = decide(m)
        print(f"Planned actions: {len(actions)}")
        for a in actions:
            print(f"  - {a['type']} ({a.get('reason','')})")
