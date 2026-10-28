#!/usr/bin/env python3
"""Rebuild worker — слухає cybra:rebuild:queue, робить rebuild _master.json."""
import os, sys, json, time, subprocess
from pathlib import Path

CYBRA = Path(os.environ.get("HOME")) / "CYBRA"
os.chdir(CYBRA)

import redis
r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)
QUEUE = "cybra:rebuild:queue"
DONE = "cybra:rebuild:done"
LOG = CYBRA / "logs/rebuild_worker.log"
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(m):
    t = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    line = f"[{t}] {m}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

def rebuild():
    t0 = time.time()
    items = []
    for d in sorted((CYBRA/"modules").glob("module_*")):
        mp = d/"main.sh"
        if not mp.exists(): continue
        try: n = int(d.name.split("_")[1])
        except: continue
        if 200 <= n <= 272:
            try:
                rr = subprocess.run(["bash", str(mp), "list"], capture_output=True, timeout=5, input="")
                items.append({"id": f"module_{n:03d}", "kind": "module",
                              "ok": rr.returncode == 0, "detail": f"rc={rr.returncode}", "target": str(mp)})
            except subprocess.TimeoutExpired:
                items.append({"id": f"module_{n:03d}", "kind": "module",
                              "ok": False, "detail": "timeout", "target": str(mp)})
        elif 1 <= n <= 160:
            rr = subprocess.run(["bash", "-n", str(mp)], capture_output=True)
            items.append({"id": f"module_{n:03d}", "kind": "module",
                          "ok": rr.returncode == 0, "detail": "syntax" if rr.returncode else "ok",
                          "target": str(mp)})
    try:
        rr = subprocess.run(["pm2", "jlist"], capture_output=True, text=True, timeout=10)
        # cron-only processes: stopped між запусками — це норма
        CRON_OK = {"cybra-degrade-guard"}
        for p in json.loads(rr.stdout):
            status = p["pm2_env"]["status"]
            is_cron = p["name"] in CRON_OK or p["name"].endswith("-cron")
            ok = status == "online" or (is_cron and status == "stopped")
            items.append({"id": f"pm2_{p['name']}", "kind": "pm2",
                          "ok": ok, "detail": status + (" (cron)" if is_cron else "")})
    except: pass

    total = len(items); passed = sum(1 for i in items if i["ok"])
    pct = round(passed*100/total, 1) if total else 0
    bk = {}
    for i in items:
        bk.setdefault(i["kind"], {"total":0,"passed":0})
        bk[i["kind"]]["total"] += 1
        if i["ok"]: bk[i["kind"]]["passed"] += 1

    out = CYBRA/"state/snapshots/_master.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({
        "ts": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime()),
        "total": total, "passed": passed, "pct": pct,
        "by_kind": bk, "items": items,
    }, indent=2, ensure_ascii=False))
    dur = round(time.time() - t0, 1)
    log(f"rebuild done: {passed}/{total} = {pct}% in {dur}s")
    return {"pct": pct, "passed": passed, "total": total, "duration_s": dur}

log("rebuild worker started")
while True:
    try:
        # спочатку fix (пріоритет)
        raw_fix = r.lpop("cybra:fix:queue")
        if raw_fix:
            log(f"fix: {raw_fix[:100]}")
            subprocess.run(["bash", str(CYBRA/"fix_case_handler.sh")], timeout=120, capture_output=True)

        raw = r.blpop(QUEUE, timeout=5)
        if not raw: continue
        _, task_raw = raw
        try: task = json.loads(task_raw)
        except: task = {}
        log(f"task: {task_raw[:200]}")
        result = rebuild()
        # записуємо в done + в парламент results
        r.hset(DONE, "last", json.dumps(result))
        r.rpush("cybra:parliament:results", json.dumps({
            "topic": task.get("topic", "rebuild"),
            "type": "rebuild_done",
            "status": "executed",
            "execution": {"ok": True, "stdout": json.dumps(result), "stderr": ""},
            "time": time.time(),
        }))
    except Exception as e:
        log(f"ERR: {e}")
        time.sleep(5)
