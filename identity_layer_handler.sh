#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"
mkdir -p state/identity state/layers

python3 - <<'PY'
import hashlib, json, subprocess, os
from pathlib import Path
from datetime import datetime, timezone
CYBRA = Path.home()/"CYBRA"
REG = {"modules":{}, "configs":{}, "scripts":{}}
def chash(p):
    try: return hashlib.sha256(Path(p).read_bytes()).hexdigest()[:16]
    except: return "missing"
def mk(kind, role, ch): return hashlib.sha256(f"{kind}:{role}:{ch}".encode()).hexdigest()[:16]

for d in sorted((CYBRA/"modules").glob("module_*")):
    m = d/"main.sh"
    if not m.exists(): continue
    ch = chash(m)
    nn = d.name.split("_")[1]
    try: n = int(nn)
    except: n = 0
    role = "core" if 1<=n<=160 else "taxi" if 200<=n<=272 else "payment" if 280<=n<=282 else "program"
    uid = mk("module", role, ch)
    REG["modules"][uid] = {"id":uid,"path":str(m),"dir":d.name,"role":role,"content_hash":ch,"size":m.stat().st_size,"n":n}

for c in (CYBRA/"state").rglob("*.json"):
    if not c.is_file(): continue
    ch = chash(c)
    uid = mk("config", "system", ch)
    if uid in REG["configs"]:
        REG["configs"][uid].setdefault("duplicates",[]).append(str(c)); continue
    REG["configs"][uid] = {"id":uid,"path":str(c),"content_hash":ch,"size":c.stat().st_size,"duplicates":[]}

for s in list((CYBRA/"bin").glob("*.sh")) + list((CYBRA/"bin").glob("*.py")):
    ch = chash(s); uid = mk("script","tool",ch)
    REG["scripts"][uid] = {"id":uid,"path":str(s),"content_hash":ch,"size":s.stat().st_size}

(CYBRA/"state/identity/registry.json").write_text(json.dumps({
    "generated": datetime.now(timezone.utc).isoformat(),
    "count": {k: len(v) for k,v in REG.items()},
    "registry": REG,
}, indent=2, ensure_ascii=False))
print("REG", json.dumps({k: len(v) for k,v in REG.items()}))
PY
