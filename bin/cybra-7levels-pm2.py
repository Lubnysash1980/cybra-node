#!/usr/bin/env python3
import os, time, json, subprocess
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/7levels_pm2.log"
STATE_FILE = CYBRA / "state/7levels_state.json"

LOG.parent.mkdir(parents=True, exist_ok=True)
STATE_FILE.parent.mkdir(parents=True, exist_ok=True)

def get_ram():
    try:
        with open("/proc/meminfo") as f: m = f.read()
        total = int([l for l in m.splitlines() if "MemTotal" in l][0].split()[1])
        avail = int([l for l in m.splitlines() if "MemAvailable" in l][0].split()[1])
        return ((total - avail) / total) * 100
    except: return 85.0

def count_errors():
    """Рахує помилки в логах за останню годину"""
    err_count = 0
    for log_file in (CYBRA / "logs").glob("*.log"):
        try:
            # Швидка перевірка на наявність слів помилок
            content = log_file.read_text(errors="ignore")
            err_count += content.count("ERROR") + content.count("SyntaxError")
        except: pass
    return err_count

def calculate_level(ram, errors):
    """7 рівнів складності. Чим більше помилок, тим нижче рівень."""
    if errors > 50 or ram > 90: return 1 # Критичний
    if errors > 20 or ram > 85: return 2
    if errors > 10 or ram > 80: return 3
    if errors > 5  or ram > 75: return 4
    if errors > 2  or ram > 65: return 5
    if errors > 0  or ram > 55: return 6
    return 7 # Ідеал

def main():
    last_level = 0
    while True:
        try:
            ram = get_ram()
            errors = count_errors()
            level = calculate_level(ram, errors)
            
            if level != last_level:
                with open(LOG, "a") as f:
                    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
                    f.write(f"[{t}] 📊 RAM: {ram:.1f}% | Помилок у логах: {errors} | Рівень складності: {level}/7\n")
                
                state = {"ram": ram, "errors": errors, "level": level, "updated": datetime.now(timezone.utc).isoformat()}
                STATE_FILE.write_text(json.dumps(state, indent=2))
                last_level = level
        except Exception as e:
            pass
        time.sleep(60)

if __name__ == "__main__":
    main()
