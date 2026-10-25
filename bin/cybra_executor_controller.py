#!/usr/bin/env python3
"""Executor Controller — watches executor runs, pushes events into Parliament."""
import os, sys, json, time, subprocess, hashlib
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
PLAN = CYBRA / "state/executors/plan.json"
APPLIED = CYBRA / "state/executors/applied.json"
BLACKLIST = CYBRA / "state/executors/blacklist.json"
STATE = CYBRA / "state/executors/controller_state.json"
LOG = CYBRA / "logs/executor_controller.log"
QUEUE = "cybra:parliament:queue"
RESULTS = "cybra:parliament:results"

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {m}\n")
    print(m, flush=True)

def rd(*args):
    try:
        r = subprocess.run(["redis-cli", *args], capture_output=True, text=True, timeout=5)
        return r.stdout.strip() if r.returncode == 0 else None
    except Exception:
        return None

def redis_ok():
    return (rd("ping") or "").upper() == "PONG"

def notify(task):
    payload = json.dumps(task, ensure_ascii=False)
    if not redis_ok():
        log(f"  !! redis down, cannot notify: {task.get('kind')}")
        return False
    subprocess.run(["redis-cli", "-x", "rpush", QUEUE],
                   input=payload, text=True, capture_output=True)
    rd("hincrby", "cybra:executor:stats", task["kind"], "1")
    log(f"  → parliament: {task['kind']} (module={task.get('module','-')})")
    return True

def file_hash(p):
    if not p.exists(): return None
    return hashlib.sha256(p.read_bytes()).hexdigest()[:16]

def load_state():
    if STATE.exists():
        try: return json.loads(STATE.read_text())
        except: pass
    return {"plan_hash": None, "applied_hash": None, "blacklist_hash": None, "cycle": 0}

def save_state(s):
    STATE.write_text(json.dumps(s, indent=2))

def read_json(p):
    try: return json.loads(p.read_text()) if p.exists() else None
    except: return None

def detect_changes(prev, cur):
    events = []
    if cur["plan_hash"] != prev.get("plan_hash"):
        plan = read_json(PLAN)
        stats = plan.get("stats", {}) if plan else {}
        events.append({
            "kind": "EXECUTOR_PLAN_READY",
            "ts": datetime.now(timezone.utc).isoformat(),
            "stats": stats,
            "action": "review_plan",
            "note": f"improve={stats.get('improve',0)} keep={stats.get('keep',0)} needs_author={stats.get('needs_author',0)}",
        })
    if cur["applied_hash"] != prev.get("applied_hash"):
        applied = read_json(APPLIED)
        events.append({
            "kind": "EXECUTOR_APPLIED",
            "ts": datetime.now(timezone.utc).isoformat(),
            "improved": applied.get("improved", 0) if applied else 0,
            "applied_at": applied.get("applied_at") if applied else None,
            "action": "verify_and_lock_baseline",
        })
    if cur["blacklist_hash"] != prev.get("blacklist_hash"):
        bl = read_json(BLACKLIST) or {}
        events.append({
            "kind": "EXECUTOR_BLACKLIST",
            "ts": datetime.now(timezone.utc).isoformat(),
            "modules": list(bl.keys()),
            "action": "review_degraded_modules",
        })
    return events

def cycle():
    state = load_state()
    cur = {
        "plan_hash": file_hash(PLAN),
        "applied_hash": file_hash(APPLIED),
        "blacklist_hash": file_hash(BLACKLIST),
    }
    state["cycle"] = state.get("cycle", 0) + 1
    events = detect_changes(state, cur)
    for ev in events:
        notify(ev)
    state.update(cur)
    save_state(state)
    if not events:
        log(f"  cycle {state['cycle']}: no changes")

def status():
    s = load_state()
    plan = read_json(PLAN)
    applied = read_json(APPLIED)
    bl = read_json(BLACKLIST) or {}
    print("═══ EXECUTOR CONTROLLER ═══")
    print(f"cycle:        {s.get('cycle',0)}")
    print(f"plan_hash:    {s.get('plan_hash')}")
    print(f"applied_hash: {s.get('applied_hash')}")
    print(f"blacklist:    {len(bl)} modules")
    if plan:
        print(f"plan stats:   {plan.get('stats')}")
    if applied:
        print(f"applied:      {applied.get('improved',0)} at {applied.get('applied_at')}")
    print(f"queue len:    {rd('llen', QUEUE)}")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "cycle":
        cycle()
    elif cmd == "status":
        status()
    elif cmd == "loop":
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        log(f"═══ EXECUTOR CONTROLLER LOOP (interval={interval}s) ═══")
        while True:
            try: cycle()
            except Exception as e: log(f"ERR {e}")
            time.sleep(interval)
    else:
        print("usage: status|cycle|loop [interval]")
