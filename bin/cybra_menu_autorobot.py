#!/usr/bin/env python3
"""AUTOROBOT: COLLECTOR + CONTROLLER + AUTOROBOT для меню 160."""
import os, re, json, subprocess, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MENU  = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
TASKS = CYBRA / "parliament_core/tasks"
STATE = CYBRA / "state/menu_autorobot.json"
LOG   = CYBRA / "logs/menu_autorobot.log"
TASKS.mkdir(parents=True, exist_ok=True)
STATE.parent.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

# ТІЛЬКИ реальні маркери заглушок (без "BINMIX/EXECUTOR", бо це наш header)
STUB_RE = re.compile(
    r'AI-INTEGRATED|потребує наповнення|smart-stub v1|МОДУЛЬ.*створено заново',
    re.I,
)
REAL_HINT = re.compile(r'redis-cli|git |pm2 |free -m|df -h|python3 |cybra_|sqlite|curl|fidic', re.I)

def rd(*a):
    try:
        return subprocess.run(["redis-cli", *a], capture_output=True, text=True, timeout=5).stdout.strip()
    except Exception:
        return ""

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {m}\n")
    print(m, flush=True)

def classify(path):
    if not path or not Path(path).exists():
        return "MISSING"
    try:
        t = Path(path).read_text(errors="ignore")
    except Exception:
        return "BROKEN"
    if STUB_RE.search(t):
        return "STUB"
    if len(t) < 200:
        return "STUB"
    if REAL_HINT.search(t):
        # реальні виклики є — це REAL, навіть якщо header BINMIX
        return "REAL"
    try:
        if subprocess.run(["bash", "-n", str(path)], capture_output=True, timeout=5).returncode != 0:
            return "BROKEN"
    except Exception:
        return "BROKEN"
    return "REAL"

def parse_menu():
    items = {}
    for line in MENU.read_text(errors="ignore").splitlines():
        m = re.match(r'\s*(\d+)\)\s*(.+)', line)
        if not m: continue
        n = int(m.group(1))
        body = m.group(2)
        paths = re.findall(r'"([^"]+)"|\$(HOME\S+)', body)
        candidates = [a or os.path.expandvars("$HOME" + b) for a, b in paths]
        targets = [c for c in candidates
                   if c and "controllers/" not in c and "bin/" not in c and c.endswith(".sh")]
        if targets:
            items[n] = targets[-1]
    return items

def recently_pushed(n, ttl=900):
    v = rd("get", f"cybra:menu:pushed:{n}")
    if not v: return False
    try: return (time.time() - float(v)) < ttl
    except Exception: return False

def push_write(n, path):
    if recently_pushed(n): return False
    tid = f"AR-{n:03d}-{int(time.time())}"
    payload = {
        "id": tid, "type": "write_module", "action": "write_module",
        "topic": f"module_{n:03d}", "contract_id": "",
        "module": n,
        "dir": Path(path).parent.name if path else f"module_{n:03d}_base",
        "path": path or str(CYBRA / f"modules/module_{n:03d}_base/main.sh"),
    }
    (TASKS / f"{tid}.json").write_text(json.dumps(payload, indent=2, ensure_ascii=False))
    rd("rpush", "cybra:parliament:queue", json.dumps(payload, ensure_ascii=False))
    rd("setex", f"cybra:menu:pushed:{n}", "900", str(time.time()))
    return True

def cycle():
    items = parse_menu()
    stats = {"REAL": [], "STUB": [], "BROKEN": [], "MISSING": []}
    pushed = 0
    for n in range(1, 161):
        path = items.get(n)
        cls = classify(path)
        stats[cls].append(n)
        rd("hset", "cybra:menu:state", str(n), f"{cls}|{path or ''}")
        if cls != "REAL" and path and push_write(n, path):
            pushed += 1
    total = sum(len(v) for v in stats.values())
    real = len(stats["REAL"])
    pct = round(real * 100 / total, 1) if total else 0.0
    state = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "total": total, "real": real, "pct_100": pct, "pushed": pushed,
        "stats": {k: {"count": len(v), "sample": v[:25]} for k, v in stats.items()},
    }
    STATE.write_text(json.dumps(state, indent=2, ensure_ascii=False))
    log(f"cycle: {real}/{total} REAL ({pct}%)  STUB={len(stats['STUB'])} BROKEN={len(stats['BROKEN'])} MISSING={len(stats['MISSING'])} pushed={pushed}")
    return state

def status():
    if not STATE.exists():
        print("no state — run: cycle"); return
    d = json.loads(STATE.read_text())
    print(f"pct_100: {d['pct_100']}%  ({d['real']}/{d['total']})")
    print(f"last:    {d['ts']}  pushed={d['pushed']}")
    for k, v in d["stats"].items():
        print(f"  {k:8} {v['count']:3}  {v['sample'][:20]}")

if __name__ == "__main__":
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status": status()
    elif cmd == "cycle": cycle()
    elif cmd == "loop":
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else 120
        log(f"═══ AUTOROBOT LOOP (interval={interval}s) ═══")
        while True:
            try: cycle()
            except Exception as e: log(f"ERR {e}")
            time.sleep(interval)
    else: print("usage: status | cycle | loop [interval]")
