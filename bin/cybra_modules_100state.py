#!/usr/bin/env python3
"""Для кожного модуля: перевірки + автофікс + 100% стан + snapshot hash.
   Пише: state/modules/module_NNN.state.json, state/snapshots/module_NNN_*.json
   CLI: check [N] | fix [N] | snapshot [N] | summary | loop [sec]
"""
import os, re, sys, json, hashlib, subprocess, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"
CTRL = CYBRA / "controllers"
MENU = MODS / "module_19_contract_tui_menu/bin/cybra_menu.sh"
SPEC_TAXI = CYBRA / "state/taxi_premium_spec.json"
SPEC_ULTRA = CYBRA / "state/taxi_ultra_spec.json"
STATE = CYBRA / "state/modules"
SNAPS = CYBRA / "state/snapshots/modules"
EVENTS = CYBRA / "state/modules/_events.jsonl"
LOG = CYBRA / "logs/modules_100state.log"
for d in (STATE, SNAPS, LOG.parent): d.mkdir(parents=True, exist_ok=True)

STUB_RE = re.compile(r"AI-INTEGRATED|потребує наповнення|smart-stub v1|МОДУЛЬ.*створено заново|# BROKEN", re.I)
REAL_HINTS = ["redis-cli", "git --no-pager", "pm2 jlist", "python3 ", "cybra_", "sqlite", "curl", "fidic"]

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{t}] {m}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

def rd(*a):
    try:
        return subprocess.run(["redis-cli", *a], capture_output=True, text=True, timeout=5).stdout.strip()
    except: return ""

def find_module(n):
    """_base пріоритет, потім будь-який."""
    for pat in [f"module_{n:03d}_base", f"module_{n}_base", f"module_0{n}_base"]:
        d = MODS / pat
        if d.is_dir(): return d
    for pat in [f"module_{n:03d}_*", f"module_{n}_*"]:
        for d in sorted(MODS.glob(pat)):
            if d.is_dir(): return d
    return None

def find_ctrl(n):
    for p in (CTRL/f"module_{n:03d}.ctrl.sh", CTRL/f"premium_module_{n:03d}.ctrl.sh", CTRL/f"ultra_module_{n:03d}.ctrl.sh"):
        if p.exists(): return p
    return None

def calc_score(text):
    lines = len(text.splitlines())
    calls = sum(1 for h in REAL_HINTS if h in text)
    funcs = len(re.findall(r'^\w+\s*\(\)\s*\{', text, re.M))
    has_err = bool(re.search(r'\btrap\b|set -e|set -u|\|\| exit', text))
    has_log = bool(re.search(r'>\s*"\$LOG"|tee -a|log\(\)\s*\{', text))
    has_args = bool(re.search(r'\$\{?[1@#]\}?\b|getopts|case\s+"\$\{?1', text))
    return round(lines/10 + calls*5 + funcs*3 + (10 if has_err else 0) + (10 if has_log else 0) + (5 if has_args else 0), 2)

def in_menu(n):
    if not MENU.exists(): return False
    try:
        return bool(re.search(rf'^\s*{n}\)\s', MENU.read_text(errors="ignore"), re.M))
    except: return False

def in_spec(n):
    for sf in (SPEC_TAXI, SPEC_ULTRA):
        if sf.exists():
            try:
                d = json.loads(sf.read_text())
                if str(n) in d.get("modules", {}): return True
            except: pass
    return False

def create_ctrl(n, module_dir):
    """Автофікс: створює ctrl.sh якщо відсутній."""
    ctrl = CTRL / f"module_{n:03d}.ctrl.sh"
    if ctrl.exists(): return ctrl
    main = module_dir / "main.sh"
    ctrl.write_text(f'''#!/data/data/com.termux/files/usr/bin/bash
# auto-created by cybra_modules_100state.py
set -u
M="$1"; shift
[ -f "$M" ] || {{ echo "missing"; exit 2; }}
[ $# -gt 0 ] && A=("$@") || A=("list")
bash "$M" "${{A[@]}}" </dev/null 2>&1
exit $?
''')
    os.chmod(ctrl, 0o755)
    return ctrl

def check_module(n, auto_fix=False):
    """Перевірка + 100% стан одного модуля. auto_fix=True — лікує."""
    d = find_module(n)
    if not d:
        return {
            "module": n, "status": "missing", "ready": False, "pct_100": 0.0,
            "checks": {"exists": False}, "checked_at": datetime.now(timezone.utc).isoformat(),
        }

    main = d / "main.sh"
    checks = {
        "exists":           main.exists(),
        "syntax_ok":        False,
        "has_controller":   False,
        "in_menu_or_spec":  in_menu(n) or in_spec(n),
        "score_ge_50":      False,
        "runs_ok":          False,
        "no_stub_markers":  False,
    }
    details = {"score": 0.0, "lines": 0, "path": str(main)}

    if checks["exists"]:
        text = main.read_text(errors="ignore")
        details["lines"] = len(text.splitlines())
        details["score"] = calc_score(text)

        # syntax
        r = subprocess.run(["bash", "-n", str(main)], capture_output=True)
        checks["syntax_ok"] = r.returncode == 0

        # ctrl
        ctrl = find_ctrl(n)
        if not ctrl and auto_fix:
            ctrl = create_ctrl(n, d)
        checks["has_controller"] = ctrl is not None and ctrl.exists()

        # score
        checks["score_ge_50"] = details["score"] >= 50

        # no stubs
        checks["no_stub_markers"] = not STUB_MARKERS_HIT(text)

        # run (timeout 5)
        try:
            r = subprocess.run(["bash", str(main), "list"],
                               capture_output=True, text=True, timeout=5, input="")
            checks["runs_ok"] = r.returncode == 0 and len(r.stdout.strip()) >= 10
        except: checks["runs_ok"] = False

    passed = sum(1 for v in checks.values() if v)
    total = len(checks)
    pct = round(passed * 100 / total, 1)
    ready = (passed == total)

    state = {
        "module": n,
        "name": d.name,
        "status": "ready" if ready else "incomplete",
        "ready": ready,
        "pct_100": pct,
        "passed": passed,
        "total": total,
        "checks": checks,
        "details": details,
        "auto_fixed": auto_fix,
        "checked_at": datetime.now(timezone.utc).isoformat(),
    }
    (STATE/f"module_{n:03d}.state.json").write_text(json.dumps(state, indent=2, ensure_ascii=False))
    return state

def STUB_MARKERS_HIT(text):
    return bool(STUB_RE.search(text))

def make_snapshot(n):
    """Хеш-знімок вмісту модуля (main.sh + ctrl.sh + spec)."""
    d = find_module(n)
    if not d: return None
    files = {}
    ts = datetime.now(timezone.utc)
    for f in [d/"main.sh", find_ctrl(n)]:
        if f and f.exists():
            h = hashlib.sha256(f.read_bytes()).hexdigest()
            files[f.name] = {"hash": h[:16], "bytes": f.stat().st_size}
    files_hash = hashlib.sha256(
        json.dumps(files, sort_keys=True).encode()
    ).hexdigest()[:16]
    snap = {
        "module": n, "name": d.name, "files": files,
        "combined_hash": files_hash,
        "at": ts.isoformat(),
    }
    fname = SNAPS/f"module_{n:03d}_{ts.strftime('%Y%m%d_%H%M%S')}.json"
    fname.write_text(json.dumps(snap, indent=2, ensure_ascii=False))
    # keep only last 10 snapshots per module
    old = sorted(SNAPS.glob(f"module_{n:03d}_*.json"))[:-10]
    for o in old: o.unlink()
    return snap

def summary():
    """Загальний звіт по всіх модулях."""
    all_states = []
    for sf in sorted(STATE.glob("module_*.state.json")):
        try: all_states.append(json.loads(sf.read_text()))
        except: pass
    ready = [s for s in all_states if s["ready"]]
    incomplete = [s for s in all_states if not s["ready"]]
    avg_pct = round(sum(s["pct_100"] for s in all_states)/len(all_states), 1) if all_states else 0

    data = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "total": len(all_states),
        "ready": len(ready),
        "incomplete": len(incomplete),
        "avg_pct": avg_pct,
        "ready_modules": [s["module"] for s in ready],
        "incomplete_modules": [{"n": s["module"], "pct": s["pct_100"], "checks": s["checks"]}
                                for s in incomplete],
    }
    (STATE/"_summary.json").write_text(json.dumps(data, indent=2, ensure_ascii=False))
    return data

def discover_range():
    """Знайти всі N, які є в modules/."""
    ns = set()
    for d in MODS.glob("module_*"):
        m = re.match(r'module_0*(\d+)_', d.name)
        if m: ns.add(int(m.group(1)))
    return sorted(ns)

def log_event(state, kind="change"):
    """Записує в _events.jsonl тільки зміни."""
    line = json.dumps({
        "ts": datetime.now(timezone.utc).isoformat(),
        "module": state["module"],
        "kind": kind,
        "ready": state["ready"],
        "pct": state["pct_100"],
    })
    with open(EVENTS, "a") as f: f.write(line + "\n")

def cmd_check(n=None):
    if n:
        s = check_module(n)
        print(json.dumps(s, indent=2, ensure_ascii=False))
    else:
        ns = discover_range()
        log(f"check: {len(ns)} modules...")
        for i, n in enumerate(ns, 1):
            s = check_module(n)
            mark = "✅" if s["ready"] else "⚠️"
            if i % 20 == 0 or not s["ready"]:
                log(f"  {mark} [{n:03d}] {s['pct_100']:.0f}%  {s.get('name','?')}")
        sm = summary()
        log(f"SUMMARY: {sm['ready']}/{sm['total']} ready, avg {sm['avg_pct']}%")

def cmd_fix(n=None):
    ns = [n] if n else discover_range()
    log(f"fix: {len(ns)} modules (auto-fix ctrl.sh, syntax check)...")
    fixed = 0
    for i, n in enumerate(ns, 1):
        d = find_module(n)
        if not d: continue
        # auto-fix: ctrl
        if not find_ctrl(n):
            create_ctrl(n, d); fixed += 1
            log(f"  🔧 [{n:03d}] created ctrl.sh")
        s = check_module(n, auto_fix=True)
        if not s["ready"]:
            log(f"  ⚠️ [{n:03d}] {s['pct_100']:.0f}% — {[k for k,v in s['checks'].items() if not v]}")
    sm = summary()
    log(f"FIX RESULT: {sm['ready']}/{sm['total']} ready, fixed {fixed} ctrl.sh")

def cmd_snapshot(n=None):
    ns = [n] if n else discover_range()
    log(f"snapshot: {len(ns)} modules...")
    for i, n in enumerate(ns, 1):
        make_snapshot(n)
        if i % 20 == 0: log(f"  ... {i}/{len(ns)}")
    log(f"snapshot: done ({len(ns)} files)")

def cmd_summary():
    sm = summary()
    print(json.dumps(sm, indent=2, ensure_ascii=False))

def cmd_loop(interval=300):
    log(f"═══ 100% STATE CONTROLLER LOOP (interval={interval}s) ═══")
    while True:
        try:
            ns = discover_range()
            log(f"cycle: {len(ns)} modules")
            for n in ns:
                s = check_module(n, auto_fix=True)
                if not s["ready"]:
                    log_event(s, "incomplete")
            sm = summary()
            log(f"  SUMMARY: {sm['ready']}/{sm['total']} ready, avg {sm['avg_pct']}%")
        except Exception as e:
            log(f"ERR: {e}")
        time.sleep(interval)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "summary"
    n = None
    if len(sys.argv) > 2 and sys.argv[2].isdigit(): n = int(sys.argv[2])
    if cmd == "check": cmd_check(n)
    elif cmd == "fix": cmd_fix(n)
    elif cmd == "snapshot": cmd_snapshot(n)
    elif cmd == "summary": cmd_summary()
    elif cmd == "loop":
        i = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else 300
        cmd_loop(i)
    else:
        print("usage: check [N] | fix [N] | snapshot [N] | summary | loop [sec]")
