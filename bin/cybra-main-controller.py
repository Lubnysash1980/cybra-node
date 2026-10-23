#!/usr/bin/env python3
import os, time, json, shutil
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/main-controller.log"
STATE_FILE = CYBRA / "state/main_controller_state.json"

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
    except: return 0

def main():
    log("=== MAIN CONTROLLER STARTED ===")
    while True:
        try:
            ram = get_ram_usage()
            free = shutil.disk_usage("/data").free / (1024 * 1024)
            state = {"ram_pct": round(ram, 1), "disk_free_mb": round(free, 1), "updated": datetime.now(timezone.utc).isoformat()}
            STATE_FILE.write_text(json.dumps(state, indent=2))
            log(f"📊 Стан: RAM={ram:.1f}% | Диск={free:.1f} MB вільно")
        except Exception as e:
            log(f"❌ ПОМИЛКА: {e}")
        time.sleep(60)

if __name__ == "__main__":
    main()
