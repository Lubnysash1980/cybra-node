#!/usr/bin/env python3
import os, time, json
from pathlib import Path
from datetime import datetime

CYBRA = Path.home() / "CYBRA"
LOG = CYBRA / "logs/7levels_pm2.log"
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now().strftime("%H:%M:%S")
    print(f"[{t}] {msg}")
    with open(LOG, "a") as f: f.write(f"[{datetime.now().isoformat()}] {msg}\n")

def main():
    log("=== 7 LEVELS MANAGER STARTED ===")
    while True:
        # Читаємо RAM
        try:
            with open("/proc/meminfo") as f: m = f.read()
            total = int([l for l in m.splitlines() if "MemTotal" in l][0].split()[1])
            avail = int([l for l in m.splitlines() if "MemAvailable" in l][0].split()[1])
            ram = ((total - avail) / total) * 100
        except: ram = 85.0
        
        # Визначаємо рівень
        level = 1 if ram > 85 else 2 if ram > 80 else 3 if ram > 75 else 4 if ram > 65 else 5 if ram > 55 else 6 if ram > 45 else 7
        log(f"📊 RAM: {ram:.1f}% | Поточний рівень складності: {level}/7")
        time.sleep(60)

if __name__ == "__main__":
    try: main()
    except KeyboardInterrupt: log("Stopped.")
