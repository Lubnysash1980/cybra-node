#!/usr/bin/env python3
"""AI 100% RUNNER — читає mapping, пушить не-real модулі в HIDL/parliament,
   rebuild state_100, повторює до 100%. На 100% → lock + autopatch + exit 0."""
import os, sys, re, json, subprocess, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MAPPING = CYBRA/"state/ai_tasks/mapping.json"
TASK = CYBRA/"state/ai_tasks/cybra_100pct.json"
LOCK = CYBRA/"state/ai_tasks/cybra_100pct.lock"
STATE = CYBRA/"state/ai_tasks/cybra_100pct_state.json"
MASTER = CYBRA/"state/snapshots/_master.json"
LOG = CYBRA/"logs/ai_100pct.log"
LOG.parent.mkdir(parents=True, exist_ok=True)
STATE.parent.mkdir(parents=True, exist_ok=True)

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{t}] {m}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

def rd(*a):
    try: return subprocess.run(["redis-cli", *a], capture_output=True, text=True, timeout=5).stdout.strip()
    except: return ""

def load_task():
    try: return json.loads(TASK.read_text())
    except: return {}

def load_mapping():
    try: return json.loads(MAPPING.read_text())
    except: return None

def state_pct():
    if not MASTER.exists(): return 0.0
    try: return float(json.loads(MASTER.read_text()).get("pct", 0))
    except: return 0.0

def push_write_module(n, target):
    """Push до cybra:parliament:queue (menu-worker підхопить → AI handler)."""
    tid = f"AI100-{n:03d}-{int(time.time())}"
    payload = {
        "id": tid, "type": "write_module", "action": "write_module",
        "topic": f"module_{n:03d}", "contract_id": "",
        "module": n,
        "dir": Path(target).parent.name if target else f"module_{n:03d}_base",
        "path": target or str(CYBRA/f"modules/module_{n:03d}_base/main.sh"),
    }
    rd("rpush", "cybra:parliament:queue", json.dumps(payload, ensure_ascii=False))
    rd("setex", f"cybra:ai100:pushed:{n}", "600", str(time.time()))
    return tid

def recently_pushed(n, ttl=600):
    v = rd("get", f"cybra:ai100:pushed:{n}")
    if not v: return False
    try: return (time.time() - float(v)) < ttl
    except: return False

def rebuild_state():
    log("  rebuild state_100...")
    r = subprocess.run(["bash", str(CYBRA/"bin/cybra_autobuild_all.sh"), "--state-only"],
                      capture_output=True, text=True, timeout=300)
    if r.returncode != 0:
        log(f"  ⚠️ rebuild rc={r.returncode}")
    return state_pct()

def lock_and_finish(pct):
    """100% → lock + autopatch."""
    log(f"  🎉 100% ({pct}) — LOCK")
    LOCK.write_text(json.dumps({
        "locked_at": datetime.now(timezone.utc).isoformat(),
        "pct": pct,
        "master": str(MASTER),
    }, indent=2))
    # tag
    try:
        subprocess.run(["git","tag","-f","v3.2-ai-100pct"],
                      cwd=CYBRA, capture_output=True, timeout=10)
        subprocess.run(["git","push","origin","v3.2-ai-100pct","-f"],
                      cwd=CYBRA, capture_output=True, timeout=30)
    except: pass
    # force autopatch
    try:
        log("  → autopatch both storages")
        subprocess.run([sys.executable, str(CYBRA/"bin/cybra_autopatch_daemon.py"), "once"],
                      timeout=300)
    except Exception as e:
        log(f"  autopatch err: {e}")
    log("  ✅ DONE — v3.2-ai-100pct locked + backed up")
    return True

def cycle():
    task = load_task()
    if not task:
        log("  FATAL: task missing"); return False
    # regenerate mapping якщо > 30 хв
    if not MAPPING.exists() or time.time() - MAPPING.stat().st_mtime > 1800:
        log("  regen mapping...")
        subprocess.run([sys.executable, str(CYBRA/"bin/cybra_ai_100pct_gen.py")],
                      capture_output=True, timeout=120)
    m = load_mapping()
    if not m:
        log("  FATAL: mapping missing"); return False

    pct = state_pct()
    log(f"═══ AI 100PCT CYCLE (start pct={pct}%) ═══")
    if pct >= 100.0:
        return lock_and_finish(pct)

    # identify non-real modules
    nonreal = [(n, info) for n, info in m["modules"].items()
               if info.get("status") in ("stub","broken","missing")]
    log(f"  non-real modules: {len(nonreal)}")

    pushed = 0
    for n_str, info in nonreal:
        n = int(n_str)
        if recently_pushed(n): continue
        tid = push_write_module(n, info.get("target"))
        pushed += 1
        log(f"  → push mod{n:03d} ({info.get('status')}) tid={tid}")
        if pushed >= 20:  # батч 20, потім rebuild
            break

    if pushed == 0 and nonreal:
        log("  all recently pushed — wait")
    elif pushed == 0:
        log("  no work")

    # wait for workers
    if pushed > 0:
        log(f"  waiting 60s for workers ({pushed} tasks)...")
        time.sleep(60)

    # rebuild
    new_pct = rebuild_state()
    log(f"  new pct: {new_pct}%")
    if new_pct >= 100.0:
        return lock_and_finish(new_pct)

    STATE.write_text(json.dumps({
        "ts": datetime.now(timezone.utc).isoformat(),
        "pct": new_pct, "pushed": pushed, "nonreal_left": len(nonreal) - pushed,
    }, indent=2))
    return False

def main():
    interval = load_task().get("loop_interval_sec", 300)
    log("═══ AI 100PCT RUNNER START ═══")
    while True:
        try:
            if cycle():
                log("100% achieved — exit"); return
        except Exception as e:
            log(f"  ERR: {e}")
        log(f"  next cycle in {interval}s")
        time.sleep(interval)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "once":  cycle()
    elif cmd == "run": main()
    elif cmd == "check":
        print(f"pct: {state_pct()}  lock: {LOCK.exists()}")
        m = load_mapping()
        if m: print(f"mapping: {m['summary']}")
    else: print("usage: run|once|check")
