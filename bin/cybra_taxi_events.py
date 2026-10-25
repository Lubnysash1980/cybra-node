#!/usr/bin/env python3
"""TAXI EVENTS — обробник черги cybra:taxi:events.
   Слухає події (ride.created, ride.accepted, ride.completed, payment.charged,
   commission.paid, wallet.connected, ai.matched, rating.added, media.recorded)
   → диспатчить у модулі 240-259 → notify + log.
"""
import os, sys, re, json, subprocess, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
QUEUE = "cybra:taxi:events"
RESULTS = "cybra:taxi:events:processed"
LOG = CYBRA / "logs/taxi_events.log"
EVENTS_LOG = CYBRA / "state/taxi/events.jsonl"
SPEC = CYBRA / "state/taxi_premium_spec.json"
EVENTS_LOG.parent.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

# event → module number
EVENT_MAP = {
    "ride.created":       200,
    "ride.accepted":      212,
    "ride.completed":     213,
    "ride.cancelled":     201,
    "payment.charged":    220,
    "payment.instant":    246,
    "payment.commission": 247,
    "payment.contract":   248,
    "wallet.connected":   249,
    "wallet.removed":     249,
    "price.offered":      252,
    "price.countered":    252,
    "price.accepted":     252,
    "price.per_km":       253,
    "ai.matched":         254,
    "map.marker_added":   240,
    "map.zone_added":     241,
    "media.recorded":     244,
    "media.photo":        244,
    "rating.added":       256,
    "eco.sync":           258,
    "theme.changed":      259,
}

def log(m, to_file=True):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{t}] {m}"
    print(line, flush=True)
    if to_file:
        with open(LOG, "a") as f: f.write(line + "\n")

def rd(*a):
    try:
        return subprocess.run(["redis-cli", *a], capture_output=True, text=True, timeout=5).stdout.strip()
    except: return ""

def find_module(n):
    for pat in [f"module_{n:03d}_*", f"module_{n}_*"]:
        for d in sorted((CYBRA/"modules").glob(pat)):
            if d.is_dir() and (d/"main.sh").exists():
                return d/"main.sh"
    return None

def dispatch_event(event):
    """event = {type, data, ts, src}"""
    etype = event.get("type", "")
    data = event.get("data", {})
    mod_n = EVENT_MAP.get(etype)
    if not mod_n:
        return {"status": "ignored", "reason": f"no mapping for {etype}"}

    main = find_module(mod_n)
    if not main:
        return {"status": "fail", "reason": f"module {mod_n} not found"}

    # Map event → action + args
    args = []
    if etype.startswith("ride."):
        act = etype.split(".")[1]
        args = [str(data.get("ride_id",""))] if data.get("ride_id") else [act]
    elif etype.startswith("payment."):
        act = etype.split(".")[1]
        if act == "commission":
            args = ["commission", str(data.get("amount", 0))]
        elif act == "instant":
            args = ["instant", str(data.get("from","")), str(data.get("to","")), str(data.get("amount",0))]
        elif act == "contract":
            args = ["contract", str(data.get("amount",0)), str(data.get("driver","")), str(data.get("rider",""))]
        else:
            args = [act]
    elif etype == "wallet.connected":
        args = ["connect", str(data.get("address","")), str(data.get("role","rider"))]
    elif etype == "wallet.removed":
        args = ["remove", str(data.get("address",""))]
    elif etype == "price.offered":
        args = ["offer", str(data.get("ride_id","")), str(data.get("amount",0))]
    elif etype == "price.countered":
        args = ["counter", str(data.get("ride_id","")), str(data.get("amount",0))]
    elif etype == "price.accepted":
        args = ["accept", str(data.get("ride_id","")), str(data.get("who","client"))]
    elif etype == "price.per_km":
        args = ["per_km", str(data.get("who","client")), str(data.get("price",0))]
    elif etype == "ai.matched":
        args = ["match", str(data.get("rider_id",""))]
    elif etype == "map.marker_added":
        args = ["add", str(data.get("id","")), str(data.get("lat",0)), str(data.get("lon",0)), str(data.get("note",""))]
    elif etype == "map.zone_added":
        args = ["zones", str(data.get("id","")), str(data.get("lat",0)), str(data.get("lon",0)),
                str(data.get("radius",200)), str(data.get("reason","residential"))]
    elif etype == "media.recorded":
        args = ["record", str(data.get("duration",10))]
    elif etype == "media.photo":
        args = ["photo"]
    elif etype == "rating.added":
        args = ["add", str(data.get("who","")), str(data.get("score",5)), str(data.get("comment",""))]
    elif etype == "eco.sync":
        args = ["sync"]
    elif etype == "theme.changed":
        args = ["set", str(data.get("name","bright"))]
    else:
        args = ["list"]

    try:
        r = subprocess.run(["bash", str(main)] + args,
                           capture_output=True, text=True, timeout=30, input="")
        return {"status": "ok" if r.returncode == 0 else "fail",
                "rc": r.returncode,
                "module": mod_n,
                "args": args,
                "stdout": r.stdout[:300]}
    except subprocess.TimeoutExpired:
        return {"status": "fail", "rc": 124, "module": mod_n, "error": "timeout"}
    except Exception as e:
        return {"status": "fail", "module": mod_n, "error": str(e)[:200]}

def notify_result(event, result):
    """Notify через cybra_notify.sh (parliament + log + file)."""
    etype = event.get("type", "?")
    status = result.get("status", "?")
    level = "info"
    if status == "fail": level = "error"
    elif status == "ignored": level = "info"

    # 1. до загального notifier
    try:
        subprocess.run(["bash", str(CYBRA/"bin/cybra_notify.sh"), "send", level,
                        f"taxi.{etype} → {status} (mod{result.get('module',0)})"],
                       capture_output=True, timeout=5)
    except: pass

    # 2. до parliament:queue (щоб інші бачили)
    try:
        rd("rpush", "cybra:parliament:queue", json.dumps({
            "id": f"taxi-{event.get('id','?')}",
            "action": "taxi_event",
            "contract_id": "",
            "topic": f"taxi_{etype}",
            "module": result.get("module", 0),
            "status": status,
            "ts": datetime.now(timezone.utc).isoformat(),
        }, ensure_ascii=False))
    except: pass

def process(event):
    etype = event.get("type", "?")
    eid = event.get("id", f"EVT-{int(time.time())}")
    log(f"  process: {eid} type={etype}")

    result = dispatch_event(event)
    result["event_id"] = eid
    result["event_type"] = etype
    result["ts"] = datetime.now(timezone.utc).isoformat()

    # 1. push result в redis
    rd("rpush", RESULTS, json.dumps(result, ensure_ascii=False))
    rd("hincrby", "cybra:taxi:events:stats", f"type_{etype}", "1")
    rd("hincrby", "cybra:taxi:events:stats", f"status_{result['status']}", "1")
    rd("hincrby", "cybra:taxi:events:stats", "total", "1")

    # 2. file log
    with open(EVENTS_LOG, "a") as f:
        f.write(json.dumps({"event": event, "result": result}, ensure_ascii=False) + "\n")

    # 3. notify
    notify_result(event, result)

    log(f"  → {result['status']} mod={result.get('module','-')} rc={result.get('rc','-')}")
    return result

def main():
    log("═══ TAXI EVENTS WORKER START ═══")
    log(f"  queue:    {QUEUE}")
    log(f"  mapping:  {len(EVENT_MAP)} event types")
    while True:
        try:
            raw = rd("rpop", QUEUE)
            if not raw:
                time.sleep(2)
                continue
            try:
                event = json.loads(raw)
            except Exception as e:
                log(f"  bad json: {e}")
                rd("rpush", "cybra:taxi:events:invalid", raw)
                continue
            process(event)
        except Exception as e:
            log(f"  ERR: {e}")
            time.sleep(3)

if __name__ == "__main__":
    main()
