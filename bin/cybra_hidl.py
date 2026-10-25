#!/usr/bin/env python3
"""HIDL Dispatcher: CLI для створення HIDL-задач."""
import os, sys, json, subprocess, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
QUEUE = "cybra:hidl:queue"
SPEC = CYBRA / "state/modules_spec.json"

def rd(*a):
    try:
        return subprocess.run(["redis-cli", *a], capture_output=True, text=True, timeout=5).stdout.strip()
    except: return ""

def find_module(n):
    for pat in [f"module_{n:03d}_*", f"module_{n}_*", f"module_0{n}_*"]:
        for d in sorted((CYBRA/"modules").glob(pat)):
            if d.is_dir(): return d
    return None

def dispatch(n, action="execute", args=None, evo_check=True, git_access=True):
    d = find_module(n)
    if not d:
        print(f"❌ module {n} not found"); return False
    main = d / "main.sh"
    ctrl = CYBRA / "controllers" / f"module_{n:03d}.ctrl.sh"
    if not main.exists():
        print(f"❌ {main} missing"); return False

    spec = {}
    if SPEC.exists():
        try: spec = json.loads(SPEC.read_text()).get("modules", {}).get(str(n), {})
        except: pass

    msg = {
        "id": f"HIDL-{n:03d}-{int(time.time())}",
        "hidl_version": "1.0",
        "action": action,
        "module": n,
        "spec": spec,
        "args": args or [],
        "ctrl": str(ctrl) if ctrl.exists() else None,
        "main": str(main),
        "evo": {"check": evo_check, "threshold_pct": 3.0,
                "on_rollback": "restore_from_git"},
        "git": {"access": git_access, "repo": str(CYBRA), "branch": "main",
                "on_error": "restore"},
        "notify": {"targets": ["parliament","log","file"],
                    "queue": "cybra:parliament:queue",
                    "log": "logs/hidl.log",
                    "file": "state/hidl/events.jsonl"},
    }
    rd("rpush", QUEUE, json.dumps(msg, ensure_ascii=False))
    print(f"✅ HIDL queued: {msg['id']} module={n} action={action} ctrl={'yes' if msg['ctrl'] else 'no'}")
    return True

def main():
    if len(sys.argv) < 2:
        print("usage: cybra_hidl.py <N> [action] [args...]")
        print("  actions: execute | verify | score | restore")
        print("  examples:")
        print("    cybra_hidl.py 2 execute list")
        print("    cybra_hidl.py 25 execute add Ivan 0xABC")
        print("    cybra_hidl.py 100 verify")
        return
    n = int(sys.argv[1])
    action = sys.argv[2] if len(sys.argv) > 2 else "execute"
    args = sys.argv[3:]
    dispatch(n, action, args)

if __name__ == "__main__":
    main()
