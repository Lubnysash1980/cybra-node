#!/usr/bin/env python3
import os, time, json
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/7levels_pm2.log"
STATE_FILE = CYBRA / "state/7levels_state.json"

LOG.parent.mkdir(parents=True, exist_ok=True)
STATE_FILE.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")

def get_ram_usage():
    try:
        with open("/proc/meminfo", "r") as f:
            meminfo = f.read()
        total = int([l for l in meminfo.splitlines() if "MemTotal" in l][0].split()[1])
        available = int([l for l in meminfo.splitlines() if "MemAvailable" in l][0].split()[1])
        return ((total - available) / total) * 100
    except: return 85.0

def main():
    log("=== 7 LEVELS STARTED ===")
    last_level = 0
    while True:
        try:
            ram = get_ram_usage()
            level = 1 if ram > 85 else 2 if ram > 80 else 3 if ram > 75 else 4
            if level != last_level:
                log(f"📊 RAM: {ram:.1f}% | Рівень Складності: {level}/7")
                STATE_FILE.write_text(json.dumps({"ram": ram, "level": level}, indent=2))
                last_level = level
        except Exception as e:
            log(f"❌ ПОМИЛКА: {e}")
        time.sleep(60)

if __name__ == "__main__":
    main()
