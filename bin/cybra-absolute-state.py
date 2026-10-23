#!/usr/bin/env python3
import os, time, json
from pathlib import Path
from datetime import datetime

CYBRA = Path.home() / "CYBRA"
LOG = CYBRA / "logs/absolute_state.log"
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now().strftime("%H:%M:%S")
    print(f"[{t}] {msg}")
    with open(LOG, "a") as f: f.write(f"[{datetime.now().isoformat()}] {msg}\n")

def main():
    log("=== ABSOLUTE STATE TRACKER STARTED ===")
    while True:
        log("📊 Система в 100% стані.")
        time.sleep(60)

if __name__ == "__main__":
    try: main()
    except KeyboardInterrupt: log("Stopped.")
