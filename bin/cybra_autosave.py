#!/usr/bin/env python3
import shutil
from pathlib import Path
from datetime import datetime, timezone
PM2 = Path.home()/".pm2"; OUT = PM2/"autosave"; OUT.mkdir(parents=True, exist_ok=True)
ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
for src in (PM2/"dump.pm2", PM2/"evolution"/"score.json"):
    if src.exists():
        shutil.copy2(src, OUT/f"{ts}-{src.name}")
print(f"autosave OK → {OUT}")
