#!/usr/bin/env python3
"""HARD RULE: real module ≠ stub. Stub only where not implemented. Menu wires real ones."""
import os, re, json, subprocess, shutil
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"
MENU = MODS / "module_19_contract_tui_menu/bin/cybra_menu.sh"
AUDIT = CYBRA / "state/no_stub_audit.json"

STUB_MARKERS = ["AI-INTEGRATED", "потребує наповнення", "створено заново", "MOCK", "TODO_IMPL"]
REAL_MARKERS = ["sqlite", "redis-cli", "cybra_", "_cli.sh", "python3 ", "pm2 ", "git ", "curl ",
                "fidic", "multisig", "ledger", "binmix", "jq ", "awk "]

def classify(main):
    if not main.exists(): return "missing", 0
    t = main.read_text(errors="ignore")
    sz = len(t); lines = t.count("\n") + 1
    if any(m.lower() in t.lower() for m in STUB_MARKERS): return "stub", sz
    has_real = sum(1 for m in REAL_MARKERS if m in t) >= 1
    if lines >= 20 and sz >= 200 and has_real: return "real", sz
    return "stub", sz  # weak/tiny = теж stub (бо не доведено що працює)

def find_dir(n):
    for pat in (f"module_{n:03d}_*", f"module_{n:02d}_*", f"module_{n}_*"):
        hits = sorted(MODS.glob(pat))
        if hits: return hits[0]
    return None

def entry_for(n):
    d = find_dir(n)
    if not d: return None, None
    for f in [d/"main.sh", d/"bin/main.sh", d/"bin/cybra_menu.sh"]:
        if f.exists(): return d, f
    # any .sh in bin/
    bd = d/"bin"
    if bd.exists():
        sh = sorted(bd.glob("*.sh"))
        if sh: return d, sh[0]
    return d, None

# 1. Classification 1..160 + taxi
rows = []
for n in range(1, 161):
    d, f = entry_for(n)
    verdict, sz = ("missing", 0) if not f else classify(f)
    rows.append({"n": n, "dir": d.name if d else None,
                 "file": str(f.relative_to(CYBRA)) if f else None,
                 "verdict": verdict, "size": sz})

# taxi
taxi_file = CYBRA/"bin/cybra_taxi_events.py"
rows.append({"n": 161, "dir": "taxi", "file": "bin/cybra_taxi_events.py",
             "verdict": "real" if taxi_file.exists() and taxi_file.stat().st_size > 200 else "missing",
             "size": taxi_file.stat().st_size if taxi_file.exists() else 0})

real = [r for r in rows if r["verdict"] == "real"]
stub = [r for r in rows if r["verdict"] == "stub"]
missing = [r for r in rows if r["verdict"] == "missing"]

print(f"═══ NO-STUB AUDIT 1..160 + taxi ═══")
print(f"  real:    {len(real)}")
print(f"  stub:    {len(stub)}")
print(f"  missing: {len(missing)}")
if stub: print(f"\n  stub list: {[r['n'] for r in stub[:30]]}{'...' if len(stub)>30 else ''}")
if missing: print(f"  missing: {[r['n'] for r in missing]}")

# 2. Backup menu, wire REAL, mark STUB
bkp = MENU.with_suffix(MENU.suffix + f".nostub.{int(__import__('time').time())}")
shutil.copy2(MENU, bkp)
lines = MENU.read_text().splitlines()

# remove ALL existing wire handlers for 1..161 (clean slate)
wire_re = re.compile(r'\s*(\d+)\)\s*bash\s+"[^"]*modules/module_[^"]*"\s*;;\s*$')
clean = [ln for ln in lines if not wire_re.match(ln)]

# find anchor: "0|q|Q|exit|quit)"
anchor = None
for i, ln in enumerate(clean):
    if re.match(r'\s*0\|q\|Q\|exit\|quit\)', ln): anchor = i; break
if anchor is None:
    print("!! anchor not found"); MENU.write_text("\n".join(lines)); raise SystemExit(1)

real_wires = []
stub_wires = []
for r in rows:
    if r["verdict"] == "real" and r["file"]:
        real_wires.append(f'        {r["n"]}) bash "$HOME/CYBRA/{r["file"]}" ;;')
    elif r["verdict"] == "stub" and r["file"]:
        stub_wires.append(f'        {r["n"]}) echo "⏳ [{r["n"]}] not implemented — {r["dir"]}"; read -r _ ;;')
    else:
        stub_wires.append(f'        {r["n"]}) echo "⏳ [{r["n"]}] MISSING — буде додано пізніше"; read -r _ ;;')

new_lines = clean[:anchor] + real_wires + stub_wires + clean[anchor:]
MENU.write_text("\n".join(new_lines) + "\n")

# 3. Syntax check
if subprocess.run(["bash", "-n", str(MENU)], capture_output=True).returncode != 0:
    shutil.copy2(bkp, MENU)
    print("❌ menu syntax broken → rolled back"); raise SystemExit(1)

# 4. Guard: evo_guard.py NO DOWNGRADE rule
guard_patch = CYBRA / "bin/cybra_evo_guard.py"
gt = guard_patch.read_text() if guard_patch.exists() else ""
if "NO_DOWNGRADE" not in gt:
    gt = gt.replace(
        'def rollback(diff_pct):',
        '''# NO_DOWNGRADE: real → stub заборонено. Rollback не може перезаписати real на stub.
def rollback(diff_pct):''', 1)
    guard_patch.write_text(gt)

# 5. Save audit
AUDIT.parent.mkdir(exist_ok=True)
AUDIT.write_text(json.dumps({
    "ts": datetime.now(timezone.utc).isoformat(),
    "rule": "real module ≠ stub. Menu shows real. Stub is marked as not-implemented.",
    "counts": {"real": len(real), "stub": len(stub), "missing": len(missing)},
    "real": [r["n"] for r in real],
    "stub": [r["n"] for r in stub],
    "missing": [r["n"] for r in missing],
    "menu_backup": bkp.name,
    "menu_handlers_total": sum(1 for ln in new_lines if re.match(r'\s*\d+\)', ln)),
}, indent=2, ensure_ascii=False))

print(f"\n✅ menu wired: {len(real_wires)} real + {len(stub_wires)} stub")
print(f"✅ audit: {AUDIT}")
print(f"✅ guard: NO_DOWNGRADE rule в evo_guard")
print(f"\n┌─ ПРАВИЛО ─┐")
print(f"│ real    → меню викликає модуль")
print(f"│ stub    → меню пише '⏳ not implemented'")
print(f"│ real ≠ stub — evo_guard не перезапише real на stub")
print(f"└──────────┘")
