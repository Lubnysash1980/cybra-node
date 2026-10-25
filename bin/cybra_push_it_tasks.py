#!/usr/bin/env python3
import os, re, json, subprocess, time
from pathlib import Path
from datetime import datetime, timezone
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
TASKS = CYBRA / "parliament_core/tasks"
MODS  = CYBRA / "modules"
TASKS.mkdir(parents=True, exist_ok=True)

STUBS = [36,37,38,39,50,51,52,58,59,60,63,64,66,67,68,70,71,72,73,74,75,78,79,80,82,83,85,87,89,90]

def rd(*a):
    r = subprocess.run(["redis-cli", *a], capture_output=True, text=True, timeout=5)
    return r.stdout.strip() if r.returncode == 0 else None

pushed = 0
for n in STUBS:
    d = next(MODS.glob(f"module_0*{n}_*"), None) or next(MODS.glob(f"module_{n}_*"), None)
    if not d:
        print(f"  [{n}] NO DIR"); continue
    task_id = f"IT-WRITE-{n:03d}-{int(time.time())}"
    task = {
        "id": task_id,
        "action": "write_module",
        "kind": "IT_DEPT_WRITE_MODULE",
        "assigned_to": "parliament_it_department",
        "created_at": datetime.now(timezone.utc).isoformat(),
        "module": n,
        "dir": d.name,
        "path": str(d / "main.sh"),
        "priority": "high" if n in (36,37,60,100,149,160) else "normal",
        "requirements": {
            "must_be_real": True,
            "min_lines": 20,
            "must_use": ["#!/data/data/com.termux/files/usr/bin/bash"],
            "must_not_contain": ["AI-INTEGRATED", "потребує наповнення", "створено заново"],
            "syntax_check": "bash -n",
            "context": "CYBRA модуль системи, Termux, має взаємодіяти з redis, git, pm2, logs",
        },
        "acceptance": [
            "bash -n main.sh → OK",
            "wc -l main.sh ≥ 20",
            "grep -cE 'sqlite|cybra_|redis|python3|pm2|git' main.sh ≥ 2",
            "ручний запуск не падає за <5s",
        ],
        "status": "PENDING",
    }
    (TASKS / f"{task_id}.json").write_text(json.dumps(task, indent=2, ensure_ascii=False))
    rd("rpush", "cybra:parliament:queue", json.dumps(task, ensure_ascii=False))
    pushed += 1

rd("hset", "cybra:executor:stats", "IT_TASKS_PUSHED", str(pushed))
rd("set", "cybra:it_dept:last_batch", datetime.now(timezone.utc).isoformat())
print(f"✅ pushed {pushed} IT tasks → cybra:parliament:queue")
print(f"   files: {TASKS}/IT-WRITE-*.json")
print(f"   queue len: {rd('llen', 'cybra:parliament:queue')}")
