#!/usr/bin/env python3
import hashlib, json
from pathlib import Path
HOME = Path.home(); PM2 = HOME/".pm2"
CHECK = [HOME/"bin"/"cybra-guard", PM2/"ctl"/"parliament.token"]
out = []
for f in CHECK:
    out.append({"file": str(f), "sha": hashlib.sha256(f.read_bytes()).hexdigest()[:16] if f.exists() else None, "ok": f.exists()})
print(json.dumps({"status":"ok","files":out}, indent=2))
