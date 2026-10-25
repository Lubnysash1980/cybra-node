#!/usr/bin/env python3
"""EVO GUARD: -3% degradation => auto-rollback+blacklist; +3% evolution => lock new baseline+snapshot."""
import os, sys, re, json, subprocess
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
STATE = CYBRA / "state/executors"
BASE_FILE = STATE / "guard_baseline.json"
HISTORY   = STATE / "guard_history.jsonl"
BACKUP    = STATE / "backup"
BLACKLIST = STATE / "blacklist.json"
LOCK      = STATE / "apply.lock"
LOG       = CYBRA / "logs/evo_guard.log"
SNAP      = CYBRA / "snapshots"

STATE.mkdir(parents=True, exist_ok=True)
BACKUP.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

STUB = ["ai-integrated","статус: ready","модуль активний","згенеровано ai","module {i}"]
REAL = ["sqlite","redis-cli","curl ","wget ","cybra_contract","cybra_invoice",
        "cybra_ai_","cybra_","_cli.sh","fidic","multisig","ledger","kibra"]

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG,"a") as f: f.write(f"[{t}] {m}\n")
    print(m, flush=True)

def is_stub(t):
    low = t.lower()
    return any(m in low for m in STUB) or (len(t) < 400 and not any(m in low for m in REAL))

def measure():
    mods, total = {}, 0
    for d in sorted((CYBRA/"modules").iterdir()):
        if not d.is_dir(): continue
        m = re.match(r"module_(\d+)", d.name)
        if not m: continue
        n = int(m.group(1))
        main = d/"main.sh"
        if not main.exists(): continue
        t = main.read_text(errors="ignore")
        stub = is_stub(t); sz = len(t)
        mods[n] = {"size": sz, "real": not stub, "dir": d.name}
        total += sz if not stub else 0
    return {"score": total, "modules": mods}

def delta_pct(cur, base):
    if base["score"] <= 0: return 0.0
    return (cur["score"] - base["score"]) / base["score"] * 100.0

def latest_backup():
    bs = sorted(BACKUP.glob("modules_*.tar.gz"))
    return bs[-1] if bs else None

def rollback(diff_pct):
    b = latest_backup()
    if not b:
        log(f"🚨 ROLLBACK needed ({diff_pct:+.2f}%) — NO BACKUP"); return False
    log(f"🚨 ROLLBACK {diff_pct:+.2f}% from {b.name}")
    subprocess.run(["tar","-xzf",str(b),"-C",str(CYBRA)], check=True)
    try: bl = json.loads(BLACKLIST.read_text()) if BLACKLIST.exists() else {}
    except: bl = {}
    cur = measure(); base = json.loads(BASE_FILE.read_text())
    for n_str, info in base["modules"].items():
        n = int(n_str)
        if info.get("real") and not cur["modules"].get(n,{}).get("real",False):
            bl[str(n)] = {"reason":"degradation","ts":datetime.now(timezone.utc).isoformat(),
                          "delta_pct":round(diff_pct,2)}
    BLACKLIST.write_text(json.dumps(bl, indent=2, ensure_ascii=False))
    log(f"  blacklisted: {list(bl.keys())[:20]}{'...' if len(bl)>20 else ''}")
    return True

def lock_baseline(cur, old, diff_pct):
    log(f"🚀 EVOLUTION +{diff_pct:.2f}% — locking: {old['score']}→{cur['score']}")
    BASE_FILE.write_text(json.dumps({
        "locked_at": datetime.now(timezone.utc).isoformat(),
        "score": cur["score"], "modules": cur["modules"],
        "previous_score": old["score"],
    }, indent=2, ensure_ascii=False))
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    bkp = BACKUP / f"modules_{ts}.tar.gz"
    subprocess.run(["tar","-czf",str(bkp),"-C",str(CYBRA),"modules"], check=True)
    log(f"  backup: {bkp.name}")
    SNAP.mkdir(exist_ok=True)
    try:
        subprocess.run(["tar","-czf",str(SNAP/f"evo_lock_{ts}.tar.gz"),
                        "-C",str(CYBRA),"modules"], check=True)
    except: pass

def cycle():
    if LOCK.exists(): log("  skip: apply.lock"); return
    if not BASE_FILE.exists():
        cur = measure()
        BASE_FILE.write_text(json.dumps({
            "locked_at": datetime.now(timezone.utc).isoformat(),
            "score": cur["score"], "modules": cur["modules"],
        }, indent=2, ensure_ascii=False))
        real = sum(1 for m in cur["modules"].values() if m["real"])
        log(f"  baseline INITIALIZED: score={cur['score']} real={real}"); return
    base = json.loads(BASE_FILE.read_text()); cur = measure()
    d = delta_pct(cur, base)
    with open(HISTORY,"a") as f:
        f.write(json.dumps({"ts":datetime.now(timezone.utc).isoformat(),
                            "score":cur["score"],"baseline":base["score"],
                            "delta_pct":round(d,3)})+"\n")
    if d <= -3.0:
        if rollback(d):
            post = measure()
            BASE_FILE.write_text(json.dumps({
                "locked_at": datetime.now(timezone.utc).isoformat(),
                "score": post["score"], "modules": post["modules"],
                "previous_score": base["score"],
                "rollback_reason": f"delta {d:+.2f}%",
            }, indent=2, ensure_ascii=False))
            log(f"  baseline reset after rollback: {post['score']}")
    elif d >= 3.0:
        lock_baseline(cur, base, d)
    else:
        log(f"  OK delta={d:+.2f}% baseline={base['score']} current={cur['score']}")

def status():
    if not BASE_FILE.exists(): print("baseline: NONE"); return
    b = json.loads(BASE_FILE.read_text()); c = measure(); d = delta_pct(c, b)
    real = sum(1 for m in c["modules"].values() if m["real"])
    stub = sum(1 for m in c["modules"].values() if not m["real"])
    print(f"baseline:  score={b['score']}  locked={b['locked_at']}")
    print(f"current:   score={c['score']}  delta={d:+.2f}%  real={real} stub={stub}")
    print(f"threshold: -3% rollback | +3% lock")
    if BLACKLIST.exists():
        bl = json.loads(BLACKLIST.read_text())
        if bl: print(f"blacklist: {list(bl.keys())[:20]}{'...' if len(bl)>20 else ''}")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv)>1 else "status"
    if cmd == "cycle": cycle()
    elif cmd == "status": status()
    elif cmd == "loop":
        import time
        i = int(sys.argv[2]) if len(sys.argv)>2 else 60
        log(f"═══ EVO GUARD LOOP (interval={i}s) ═══")
        while True:
            try: cycle()
            except Exception as e: log(f"ERR {e}")
            time.sleep(i)
    else: print("usage: status|cycle|loop [interval]")
