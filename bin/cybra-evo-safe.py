#!/usr/bin/env python3
import os, time, json, subprocess
from pathlib import Path
from datetime import datetime

CYBRA = Path.home() / "CYBRA"
LOG = CYBRA / "logs/evo_safe.log"
STATE_FILE = CYBRA / "state/evo_safe_state.json"
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now().strftime("%H:%M:%S")
    print(f"[{t}] {msg}")
    with open(LOG, "a") as f: f.write(f"[{datetime.now().isoformat()}] {msg}\n")

def main():
    log("=== EVO SAFE (3% CONTROL) STARTED ===")
    if not STATE_FILE.exists():
        STATE_FILE.write_text(json.dumps({"baseline": 100.0, "history": []}))
    
    while True:
        try:
            data = json.loads(STATE_FILE.read_text())
            base = data.get("baseline", 100.0)
            
            # Імітація перевірки стану (в реальності тут перевірка PM2 та помилок)
            current = 100.0 
            diff = current - base
            
            if diff <= -3.0:
                log(f"🚨 ДЕГРАДАЦІЯ! Відкат до базового стану {base}%")
                data["history"].append({"time": datetime.now().isoformat(), "event": "rollback"})
            elif diff >= 3.0:
                log(f"🚀 ПРОГРЕС! Фіксація нового стану {current}%")
                data["baseline"] = current
                data["history"].append({"time": datetime.now().isoformat(), "event": "progress"})
            
            STATE_FILE.write_text(json.dumps(data, indent=2))
        except Exception as e:
            log(f"Error: {e}")
        time.sleep(60)

if __name__ == "__main__":
    try: main()
    except KeyboardInterrupt: log("Stopped.")
