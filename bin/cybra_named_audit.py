#!/usr/bin/env python3
"""Показати: які named модулі існують на диску, які зараз wire, що можна підключити."""
import os, re, json
from pathlib import Path
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
MODS = CYBRA / "modules"

def parse_menu():
    items = {}
    for line in MENU.read_text(errors="ignore").splitlines():
        m = re.match(r'\s*(\d+)\)\s*(.+)', line)
        if not m: continue
        n = int(m.group(1))
        if n < 1 or n > 160: continue
        pm = re.search(r'"(/data/[^"]+\.sh)"', line)
        if pm: items[n] = Path(pm.group(1))
    return items

def is_real(path):
    if not path or not path.exists(): return False
    t = path.read_text(errors="ignore")
    return "── git ──" not in t or len(t) > 2500  # dashboard → не real

# знайти всі named модулі
named = {}
for d in sorted(MODS.glob("module_*_*")):
    if not d.is_dir(): continue
    m = re.match(r'module_(\d+)_(.+)', d.name)
    if not m: continue
    n = int(m.group(1))
    suffix = m.group(2)
    if suffix in ("base", "generated"): continue
    if n > 160: continue
    main = d / "main.sh"
    if not main.exists(): continue
    lines = len(main.read_text(errors="ignore").splitlines())
    named.setdefault(n, []).append({
        "dir": d.name, "suffix": suffix, "lines": lines,
        "path": str(main), "is_real": is_real(main)
    })

current = parse_menu()

print("═══ NAMED MODULES ON DISK ═══")
print(f"всього named модулів (унікальних N): {len(named)}")
print()

# для кожного N: чи wired на named? чи на _base?
wired_named, wired_base, conflict = [], [], []
for n in range(1, 161):
    if n not in named: continue
    cur_path = current.get(n)
    cur_dir = cur_path.parent.name if cur_path else "?"
    if cur_dir.startswith(f"module_{n}_") and not cur_dir.endswith(("_base", "_generated")):
        wired_named.append(n)
    elif cur_dir == f"module_{n}_base" or cur_dir.endswith("_base"):
        wired_base.append(n)
    else:
        conflict.append((n, cur_dir))

print(f"── підключено на named: {len(wired_named)} ──")
for n in wired_named[:20]:
    print(f"  [{n:>3}] {current[n].parent.name}")

print(f"\n── підключено на _base але є named на диску: {len(wired_base)} (треба переключити) ──")
for n in wired_base[:40]:
    variants = named[n]
    best = max(variants, key=lambda v: v["lines"])
    print(f"  [{n:>3}] зараз {current[n].parent.name:<30} → є: {best['dir']} ({best['lines']}L)")


# звіт
out = CYBRA / "state/named_audit.json"
out.write_text(json.dumps({
    "named_on_disk": {str(k): v for k, v in named.items()},
    "wired_named": wired_named,
    "wired_base_but_named_exists": wired_base,
    "conflict": conflict,
}, indent=2, ensure_ascii=False))
print(f"\n→ {out}")
