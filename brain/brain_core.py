#!/usr/bin/env python3
import os, sys, json, subprocess, time, re
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
BRAIN = CYBRA / "brain"
STATE_FILE = BRAIN / "state/brain_state.json"
LOG = BRAIN / "logs/brain.log"

def log(msg):
    LOG.parent.mkdir(exist_ok=True)
    with open(LOG, "a") as f:
        f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")
    print(f"  [BRAIN] {msg}")

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

def load_state():
    if STATE_FILE.exists():
        try: return json.loads(STATE_FILE.read_text())
        except: pass
    return {"cycles": 0, "last_actions": []}

def save_state(state):
    STATE_FILE.parent.mkdir(exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

def collect_metrics():
    m = {"pm2": [], "git": "unknown", "modules": 0, "conflicts": 0, "evo_snapshots": 0}
    r = run("pm2 jlist")
    if r.returncode == 0:
        try:
            for p in json.loads(r.stdout):
                m["pm2"].append({"name": p["name"], "status": p["pm2_env"]["status"]})
        except: pass
    if (CYBRA / ".git").exists():
        r = run("git remote -v", cwd=CYBRA)
        m["git"] = "ok" if "origin" in r.stdout else "no_remote"
    else:
        m["git"] = "no_git"
    reg_file = CYBRA / "parliament_core/registry.json"
    if reg_file.exists():
        try:
            reg = json.loads(reg_file.read_text())
            m["modules"] = reg.get("total_modules", 0)
            m["conflicts"] = reg.get("conflicts", 0)
        except: pass
    snaps = list((CYBRA / "hashes/snapshots").glob("snapshot_*.json"))
    m["evo_snapshots"] = len(snaps)
    return m

def decide(metrics):
    actions = []
    offline = [p["name"] for p in metrics["pm2"] if p["status"] != "online"]
    if offline:
        actions.append({"type": "pm2_restart", "target": offline})
    if metrics["git"] != "ok":
        actions.append({"type": "fix_git"})
    if metrics["conflicts"] > 20:
        actions.append({"type": "clean_conflicts"})
    return actions

def execute(actions):
    for a in actions:
        log(f"EXEC: {a['type']}")
        if a["type"] == "pm2_restart":
            for n in a["target"]: run(f"pm2 restart {n}")
        elif a["type"] == "fix_git":
            run("git remote remove origin", cwd=CYBRA)
            run("git remote add origin https://github.com/Lubnysash1980/cybra-node.git", cwd=CYBRA)
        elif a["type"] == "clean_conflicts":
            run("python3 ~/CYBRA/parliament_core/priority_manager.py clean")

def daemon():
    log("Brain started.")
    state = load_state()
    while True:
        state["cycles"] += 1
        try:
            metrics = collect_metrics()
            actions = decide(metrics)
            if actions:
                execute(actions)
                state["last_actions"] = actions
            else:
                log(f"Cycle {state['cycles']}: all OK")
            save_state(state)
        except Exception as e:
            log(f"ERROR: {e}")
        time.sleep(120)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "daemon":
        daemon()
    else:
        m = collect_metrics()
        print(f"PM2: {len([p for p in m['pm2'] if p['status']=='online'])}/{len(m['pm2'])} online")
        print(f"Git: {m['git']}")
        print(f"Modules: {m['modules']}")
        print(f"Conflicts: {m['conflicts']}")
        print(f"Snapshots: {m['evo_snapshots']}")
