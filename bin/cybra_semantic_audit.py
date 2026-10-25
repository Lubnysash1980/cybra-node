#!/usr/bin/env python3
"""Семантичний аудит 160 модулів: named vs _base, чи є контролер, чи є spec."""
import os, re, json
from pathlib import Path
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
CTRL = CYBRA / "controllers"
SPEC = CYBRA / "state/modules_spec.json"
CTRL.mkdir(exist_ok=True)
STATE = CYBRA / "state"; STATE.mkdir(exist_ok=True)

# мапа "номер → очікувана функція" з назв модулів (named)
def purpose_from_name(dirname):
    """module_25_address_book → '25_address_book' → 'address_book'"""
    m = re.match(r'module_\d+_(.+)', dirname)
    if not m: return None
    suffix = m.group(1)
    if suffix in ('base', 'generated'): return None  # без семантики
    return suffix.replace('_', ' ')

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

def analyze_module(path):
    if not path or not path.exists():
        return {"exists": False}
    t = path.read_text(errors="ignore")
    real_calls = len(re.findall(r'redis-cli|git --no-pager|pm2 jlist|python3 |cybra_|sqlite|curl|fidic', t))
    functions = len(re.findall(r'^\w+\s*\(\)\s*\{', t, re.M))
    has_err = bool(re.search(r'\btrap\b|set -e|set -u|\|\| exit', t))
    has_log = bool(re.search(r'>\s*"\$LOG"|tee -a|log\(\)\s*\{', t))
    return {
        "exists": True,
        "lines": len(t.splitlines()),
        "real_calls": real_calls,
        "functions": functions,
        "has_err": has_err,
        "has_log": has_log,
        "is_dashboard": "── git ──" in t and "── redis ──" in t and "── pm2 ──" in t,
    }

def main():
    items = parse_menu()
    modules = {}
    for n in range(1, 161):
        path = items.get(n)
        # знайти dirname
        dirname = None
        if path:
            dirname = path.parent.name
        else:
            for d in (CYBRA/"modules").glob(f"module_0*{n}_*"):
                if d.is_dir(): dirname = d.name; break

        purpose = purpose_from_name(dirname) if dirname else None
        ctrl_path = CTRL / f"module_{n:03d}.ctrl.sh"
        analysis = analyze_module(path)

        # статус
        if not analysis.get("exists"):
            status = "MISSING"
        elif purpose and not analysis.get("is_dashboard"):
            status = "NAMED_REAL"  # має назву і не dashboard → ймовірно реальний
        elif purpose and analysis.get("is_dashboard"):
            status = "NAMED_DASHBOARD"  # має назву але dashboard → треба семантики
        elif not purpose and analysis.get("is_dashboard"):
            status = "GENERIC_DASHBOARD"  # _base + dashboard → треба визначити семантику
        else:
            status = "UNKNOWN"

        modules[n] = {
            "n": n, "dirname": dirname, "path": str(path) if path else None,
            "purpose": purpose,  # None якщо _base
            "status": status,
            "has_controller": ctrl_path.exists(),
            "analysis": analysis,
        }

    # зведення
    summary = {
        "NAMED_REAL":       [n for n, m in modules.items() if m["status"] == "NAMED_REAL"],
        "NAMED_DASHBOARD":  [n for n, m in modules.items() if m["status"] == "NAMED_DASHBOARD"],
        "GENERIC_DASHBOARD":[n for n, m in modules.items() if m["status"] == "GENERIC_DASHBOARD"],
        "MISSING":          [n for n, m in modules.items() if m["status"] == "MISSING"],
        "with_controller":  [n for n, m in modules.items() if m["has_controller"]],
    }

    SPEC.write_text(json.dumps({"modules": modules, "summary": summary,
                                "ts": __import__("datetime").datetime.now().isoformat()},
                               indent=2, ensure_ascii=False))

    # вивід
    print("═══ SEMANTIC AUDIT ═══")
    print(f"total modules:      160")
    print(f"NAMED_REAL:         {len(summary['NAMED_REAL']):>3}  ({[modules[n]['dirname'] for n in summary['NAMED_REAL'][:5]]})")
    print(f"NAMED_DASHBOARD:    {len(summary['NAMED_DASHBOARD']):>3}  (має назву але dashboard → треба реальної функції)")
    print(f"GENERIC_DASHBOARD:  {len(summary['GENERIC_DASHBOARD']):>3}  (_base без семантики → треба визначити)")
    print(f"MISSING:            {len(summary['MISSING']):>3}")
    print(f"with_controller:    {len(summary['with_controller']):>3}  (мають .ctrl.sh)")
    print()
    print("── named модулі (топ-20) ──")
    for n in summary["NAMED_REAL"][:10]:
        m = modules[n]
        print(f"  [{n:>3}] {m['dirname']:<40} → purpose: {m['purpose']}")
    for n in summary["NAMED_DASHBOARD"][:10]:
        m = modules[n]
        print(f"  [{n:>3}] {m['dirname']:<40} → purpose: {m['purpose']}  ⚠️ dashboard")
    print()
    print("── _base модулі (топ-20, треба визначити семантику) ──")
    for n in summary["GENERIC_DASHBOARD"][:20]:
        m = modules[n]
        print(f"  [{n:>3}] {m['dirname']}")
    print()
    print(f"→ spec: {SPEC}")

if __name__ == "__main__":
    main()
