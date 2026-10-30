#!/usr/bin/env python3
"""AUTOBUILD via PARLIAMENT: ставить задачі в parliament queue, парламент виконує,
evo_guard слідкує за score. Зупиняється коли score=100% або stubs=0 або 3 цикли без прогресу."""
import os, re, json, subprocess, time, sys
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"
TASKS = CYBRA / "parliament_core/tasks"
REPORT = CYBRA / "state/autobuild_parliament.json"
TASKS.mkdir(parents=True, exist_ok=True)

STUB = ["ai-integrated","потребує наповнення","створено заново","mock","todo_impl","autobuild fallback"]
REAL = ["sqlite","redis-cli","cybra_","_cli.sh","python3 ","pm2 ","git ","curl ",
        "fidic","multisig","ledger","binmix","jq ","awk "]

def rd(*a, timeout=10):
    try:
        r = subprocess.run(["redis-cli", *a], capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except: return ""

def score():
    try: return float(json.loads((Path(os.environ["HOME"])/".pm2/evolution/score.json").read_text())["score_pct"])
    except: return 0.0

def is_stub(t):
    low = t.lower()
    if any(m in low for m in STUB): return True
    return len(t) < 300 or not any(m in t for m in REAL)

def name_for(n):
    try:
        for r in json.loads((CYBRA/"audit/base-map.json").read_text()):
            if r["n"] == n: return r.get("name") or f"item_{n}"
    except: pass
    return f"item_{n}"

def find_module_dir(n):
    """Точний пошук module_NNN_* або module_NN_* або module_N_*."""
    for pat in (f"module_{n:03d}_*", f"module_{n:02d}_*", f"module_{n}_*"):
        hits = sorted(MODS.glob(pat))
        if hits: return hits[0]
    return None

def scan_stubs():
    stubs = []
    seen = set()
    for n in range(1, 161):
        d = find_module_dir(n)
        if not d or d.name in seen: continue
        seen.add(d.name)
        f = d / "main.sh"
        if not f.exists():
            stubs.append({"n": n, "dir": d.name, "path": str(f), "reason": "no_file"})
            continue
        if is_stub(f.read_text(errors="ignore")):
            stubs.append({"n": n, "dir": d.name, "path": str(f), "reason": "stub"})
    return stubs

def push_task(task):
    tid = task["id"]
    (TASKS / f"{tid}.json").write_text(json.dumps(task, indent=2, ensure_ascii=False))
    rd("-x", "rpush", "cybra:parliament:queue", json.dumps(task, ensure_ascii=False))

def queue_len(): return int(rd("llen", "cybra:parliament:queue") or 0)
def results_len(): return int(rd("llen", "cybra:parliament:results") or 0)

def wait_drain(max_wait=180, poll=5):
    t0 = time.time()
    while time.time() - t0 < max_wait:
        q = queue_len()
        if q == 0: return True
        time.sleep(poll)
    return False

def main():
    print(f"═══ AUTOBUILD via PARLIAMENT ═══")
    print(f"  start score: {score()}%")

    # 1. Перевірка парламенту
    jl = []
    try: jl = json.loads(subprocess.check_output(["pm2","jlist"], stderr=subprocess.DEVNULL, timeout=10) or b"[]")
    except: pass
    parliament = next((p for p in jl if p.get("name") == "parliament"), None)
    if not parliament or parliament.get("pm2_env",{}).get("status") != "online":
        print("  ❌ parliament не online — стартую")
        subprocess.run(["pm2","start","parliament"], capture_output=True, timeout=15)
        time.sleep(3)

    # 2. Scan stubs
    stubs = scan_stubs()
    print(f"  stubs: {len(stubs)}")

    # 3. Push IT-WRITE tasks for every stub
    pushed = 0
    for s in stubs:
        task_id = f"IT-WRITE-{s['n']:03d}-{int(time.time())}"
        task = {
            "id": task_id, "type": "write_module", "action": "write_module",
            "contract_id": "", "module": s["n"], "dir": s["dir"], "path": s["path"],
            "reason": s["reason"],
            "requirements": {"must_be_real": True, "min_lines": 20, "min_bytes": 300,
                             "must_use": ["redis|git|pm2|python3|sqlite|cybra_"],
                             "must_not_contain": STUB},
        }
        push_task(task)
        pushed += 1
    print(f"  pushed: {pushed} tasks")

    # 4. Wait for parliament to drain
    drained = wait_drain(max_wait=240)
    print(f"  drained: {drained}  (queue={queue_len()})")

    # 5. Rescan
    stubs_after = scan_stubs()
    print(f"  stubs after: {len(stubs_after)}")

    # 6. Run evo to verify score
    subprocess.run(["python3", str(CYBRA/"bin/cybra_evolution_controller.py"), "once"],
                   capture_output=True, timeout=30)
    final_score = score()
    print(f"  score after: {final_score}%")

    # 7. Report
    report = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "stubs_before": len(stubs),
        "pushed": pushed,
        "drained": drained,
        "stubs_after": len(stubs_after),
        "score_before": 0,  # filled below
        "score_after": final_score,
        "remaining": [s["n"] for s in stubs_after],
    }
    REPORT.write_text(json.dumps(report, indent=2, ensure_ascii=False))
    print(f"  → {REPORT}")

    # 8. Loop until 100% / no progress / 3 attempts
    if len(stubs_after) == 0 and final_score >= 99:
        print(f"✅ DONE: 0 stubs, score {final_score}%")
        return 0
    if len(stubs_after) >= len(stubs):
        print(f"⚠ no progress (before={len(stubs)} after={len(stubs_after)})")
        return 1
    print(f"⚠ progress: {len(stubs)}→{len(stubs_after)}, {final_score}% — need another cycle")
    return 2

if __name__ == "__main__":
    sys.exit(main())
