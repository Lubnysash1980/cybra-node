#!/usr/bin/env python3
"""HIDL Worker: читає queue, валідує schema, передає executor, пише response."""
import os, re, sys, json, subprocess, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA  = Path(os.environ["HOME"]) / "CYBRA"
QUEUE  = "cybra:hidl:queue"
RESULTS= "cybra:hidl:results"
LOG    = CYBRA / "logs/hidl.log"
EVENTS = CYBRA / "state/hidl/events.jsonl"
EVENTS.parent.mkdir(parents=True, exist_ok=True)

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{t}] {m}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

def rd(*a):
    try:
        return subprocess.run(["redis-cli", *a], capture_output=True, text=True, timeout=5).stdout.strip()
    except: return ""

def validate(msg):
    """Базова HIDL-валідація."""
    if not isinstance(msg, dict): return False, "not a dict"
    if msg.get("hidl_version") != "1.0": return False, f"bad version {msg.get('hidl_version')}"
    if msg.get("action") not in ("execute","verify","restore","notify","score"):
        return False, f"bad action {msg.get('action')}"
    if not isinstance(msg.get("module"), int) or not (1 <= msg["module"] <= 160):
        return False, f"bad module {msg.get('module')}"
    return True, "ok"

def run_executor(msg):
    """Передає у executor, повертає response dict."""
    executor = CYBRA / "bin/cybra_hidl_executor.py"
    if not executor.exists():
        return {"status":"fail","error":"executor not found"}
    try:
        r = subprocess.run([sys.executable, str(executor)],
                           input=json.dumps(msg, ensure_ascii=False),
                           capture_output=True, text=True, timeout=60)
        if r.returncode != 0:
            return {"status":"fail","rc":r.returncode,
                    "stderr": r.stderr[-500:], "stdout": r.stdout[-500:]}
        try:
            return json.loads(r.stdout)
        except:
            return {"status":"fail","error":"executor bad json","raw": r.stdout[-300:]}
    except subprocess.TimeoutExpired:
        return {"status":"fail","error":"timeout 60s"}
    except Exception as e:
        return {"status":"fail","error":str(e)}

def write_response(msg, resp):
    resp["id"] = msg.get("id", "?")
    resp["module"] = msg.get("module", 0)
    resp["hidl_version"] = "1.0"
    resp["response_at"] = datetime.now(timezone.utc).isoformat()
    # queue
    rd("rpush", RESULTS, json.dumps(resp, ensure_ascii=False))
    # file event
    with open(EVENTS, "a") as f:
        f.write(json.dumps({"type":"response", **resp}, ensure_ascii=False) + "\n")
    # parliament
    if "parliament" in msg.get("notify", {}).get("targets", []):
        q = msg["notify"].get("queue", "cybra:parliament:queue")
        rd("rpush", q, json.dumps({
            "id": resp["id"], "action": "hidl_result",
            "contract_id": "", "module": resp["module"],
            "status": resp["status"], "rc": resp.get("rc", 0),
            "topic": f"hidl_module_{resp['module']:03d}",
            "ts": resp["response_at"]
        }, ensure_ascii=False))

def main():
    log("═══ HIDL WORKER START ═══")
    while True:
        try:
            raw = rd("rpop", QUEUE)
            if not raw:
                time.sleep(2); continue
            try:
                msg = json.loads(raw)
            except Exception as e:
                log(f"  bad json: {e}"); continue

            ok, why = validate(msg)
            if not ok:
                log(f"  invalid hidl: {why}")
                rd("rpush", "cybra:hidl:invalid", raw)
                continue

            log(f"  HIDL: {msg.get('id')} action={msg['action']} module={msg['module']}")
            resp = run_executor(msg)
            write_response(msg, resp)
            log(f"  → {resp.get('status')} rc={resp.get('rc')} delta={resp.get('delta_pct')}")
        except Exception as e:
            log(f"  ERR: {e}")
            time.sleep(3)

if __name__ == "__main__":
    main()
