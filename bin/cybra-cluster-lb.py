#!/usr/bin/env python3
import os, time, json, socket
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
HB_DIR = CYBRA / "nodes" / "heartbeats"
DEVICE_ID = "node_1" # Фіксоване ім'я для цього пристрою
LOG = CYBRA / "logs/cluster_lb.log"

HB_DIR.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")

def main():
    log(f"=== CLUSTER LB STARTED ({DEVICE_ID}) ===")
    while True:
        try:
            hb_file = HB_DIR / f"{DEVICE_ID}.json"
            hb_file.write_text(json.dumps({"device": DEVICE_ID, "last_seen": time.time()}))
        except Exception as e:
            log(f"❌ ПОМИЛКА: {e}")
        time.sleep(60)

if __name__ == "__main__":
    main()
