#!/usr/bin/env python3
"""HIDL Notifier: читає results → сповіщає (parliament, log, file, stats)."""
import os, sys, json, subprocess, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
RESULTS = "cybra:hidl:results"
STATS = "cybra:hidl:stats"
LOG = CYBRA / "logs/hidl_notifier.log"
NOTIF_LOG = CYBRA / "state/hidl/notifications.jsonl"
NOTIF_LOG.parent.mkdir(parents=True, exist_ok=True)

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{t}] {m}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

def rd(*a):
    try:
        return subprocess.run(["redis-cli", *a], capture_output=True, text=True, timeout=5).stdout.strip()
    except: return ""

def notify(resp):
    status = resp.get("status", "?")
    delta = resp.get("delta_pct", 0)
    n = resp.get("module", 0)
    level = "info"
    if status == "fail": level = "error"
    elif status == "rolled_back": level = "warn"
    elif status in ("degraded",): level = "warn"
    elif status == "improved" or delta >= 3: level = "success"

    # 1. stats
    rd("hincrby", STATS, f"status_{status}", "1")
    rd("hincrby", STATS, "total", "1")
    if delta:
        rd("hincrbyfloat", STATS, "delta_sum", str(delta))

    # 2. file
    entry = {"ts": datetime.now(timezone.utc).isoformat(),
             "level": level, "id": resp.get("id"),
             "module": n, "status": status, "rc": resp.get("rc"),
             "delta_pct": delta, "elapsed": resp.get("elapsed_sec"),
             "git_restore": resp.get("git_restore", False)}
    with open(NOTIF_LOG, "a") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    # 3. parliament (тільки warn/error/success з delta>3)
    if level in ("warn", "error") or delta >= 3.0:
        rd("rpush", "cybra:parliament:queue", json.dumps({
            "id": f"notify-{resp.get('id')}",
            "action": "hidl_notification",
            "contract_id": "",
            "topic": f"module_{n:03d}_{status}",
            "level": level,
            "delta_pct": delta,
            "module": n,
            "ts": entry["ts"],
        }, ensure_ascii=False))

    log(f"  notify [{level}] {resp.get('id')} module={n} status={status} delta={delta:+.2f}%")

def main():
    log("═══ HIDL NOTIFIER START ═══")
    while True:
        try:
            raw = rd("rpop", RESULTS)
            if not raw:
                time.sleep(2); continue
            try:
                resp = json.loads(raw)
            except Exception as e:
                log(f"  bad json: {e}"); continue
            notify(resp)
        except Exception as e:
            log(f"  ERR: {e}")
            time.sleep(3)

if __name__ == "__main__":
    main()
