#!/usr/bin/env python3
import os, re, subprocess
from pathlib import Path
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"

have, missing_main, missing_all = [], [], []
for d in sorted(MODS.iterdir()):
    if not d.is_dir(): continue
    m = re.match(r"module_(\d+)", d.name)
    if not m: continue
    n = int(m.group(1)); have.append(n)
    if not (d / "main.sh").exists(): missing_main.append(n)

present = set(have)
for n in range(1, 281):
    if n not in present: missing_all.append(n)

print(f"модулів з папкою:    {len(have)}")
print(f"  без main.sh:       {len(missing_main)}  → {missing_main[:15]}")
print(f"1..280 без папки:    {len(missing_all)}")

if missing_main:
    print(f"\n→ генерую мінімальні main.sh для {len(missing_main)} модулів")
    for n in missing_main:
        d = next(MODS.glob(f"module_0*{n}"), None) or next(MODS.glob(f"module_{n}"), None)
        if not d: continue
        p = d / "main.sh"
        p.write_text(f'''#!/data/data/com.termux/files/usr/bin/bash
# AUTO-PLACEHOLDER: needs real logic
echo "module_{n:03d}: потребує наповнення"
read -r -p "Enter..." _
''')
        os.chmod(p, 0o755)
    print("✅ готово — модулі тепер мають main.sh, меню не падає")
