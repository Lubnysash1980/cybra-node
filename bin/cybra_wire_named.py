#!/usr/bin/env python3
"""Переписати wire: N) ..._base → N) ..._named (якщо named є)."""
import os, re, shutil, subprocess, time, json
from pathlib import Path

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
MODS = CYBRA / "modules"
CTRL = CYBRA / "controllers/module-controller.sh"
REPORT = CYBRA / "state/wire_named_report.json"

# знайти найкращий named для N
def find_named(n):
    best = None
    for d in MODS.glob(f"module_0*{n}_*"):
        if not d.is_dir(): continue
        suffix = re.sub(rf"^module_0*{n}_", "", d.name)
        if suffix in ("base", "generated"): continue
        main = d / "main.sh"
        if not main.exists(): continue
        lines = len(main.read_text(errors="ignore").splitlines())
        if best is None or lines > best[1]:
            best = (d, lines, str(main))
    return best

bkp = MENU.with_suffix(MENU.suffix + f".bak.{int(time.time())}")
shutil.copy2(MENU, bkp)

lines = MENU.read_text().splitlines()
new_lines = []
replaced = []
wired_re = re.compile(r'(\s*)(\d+)\)\s+(.+)$')

for line in lines:
    m = wired_re.match(line)
    if not m:
        new_lines.append(line)
        continue
    indent, n_str, body = m.groups()
    n = int(n_str)
    if n < 1 or n > 160:
        new_lines.append(line)
        continue
    # чи це вже named?
    cur_path_m = re.search(r'"(/data/[^"]+\.sh)"', body)
    if not cur_path_m:
        new_lines.append(line)
        continue
    cur_path = Path(cur_path_m.group(1))
    cur_dir = cur_path.parent.name
    if not cur_dir.endswith(("_base", "_generated")):
        new_lines.append(line)  # вже named
        continue
    best = find_named(n)
    if not best:
        new_lines.append(line)  # нема named — лишаємо base
        continue
    d, lines_count, path = best
    # заміна
    if CTRL.exists():
        new_body = f'~/CYBRA/controllers/module-controller.sh "{path}"'
    else:
        new_body = f'bash "{path}"'
    new_lines.append(f'{indent}{n_str}) {new_body} ;;')
    replaced.append({"n": n, "from": cur_dir, "to": d.name, "lines": lines_count})

MENU.write_text("\n".join(new_lines) + "\n")

# syntax check
if subprocess.run(["bash", "-n", str(MENU)], capture_output=True).returncode != 0:
    shutil.copy2(bkp, MENU)
    print("❌ syntax broken → rolled back")
    raise SystemExit(1)

print(f"═══ WIRE NAMED ═══")
print(f"replaced: {len(replaced)}")
for r in replaced[:15]:
    print(f"  [{r['n']:>3}] {r['from']:<30} → {r['to']} ({r['lines']}L)")
if len(replaced) > 15:
    print(f"  ... +{len(replaced)-15} more")

REPORT.write_text(json.dumps({"replaced": replaced, "backup": bkp.name}, indent=2, ensure_ascii=False))
print(f"\n→ {REPORT}")
