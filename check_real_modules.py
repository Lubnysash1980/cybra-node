#!/usr/bin/env python3
import os, re
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

text = MENU.read_text()

# 1. Знайти всі функції action_*
actions = re.findall(r'^(action_[a-z0-9_]+)\(\)', text, re.MULTILINE)
print(f"═══ РЕАЛЬНІ ACTION-ФУНКЦІЇ: {len(actions)} ═══")
for a in sorted(actions):
    print(f"  🟢 {a}")

# 2. Знайти всі виклики модулів (bash "$HOME/.../main.sh")
module_calls = re.findall(r'bash\s+"\$HOME/CYBRA/modules/([^/"]+)/main\.sh"', text)
print(f"\n═══ ВИКЛИКИ ЗОВНІШНІХ МОДУЛІВ: {len(set(module_calls))} ═══")
for m in sorted(set(module_calls)):
    mod_path = CYBRA / "modules" / m / "main.sh"
    if mod_path.exists():
        size = mod_path.stat().st_size
        if size > 200:
            print(f"  🟢 {m} (main.sh, {size} bytes)")
        else:
            print(f"  🟡 {m} (main.sh, {size} bytes — ЗАГЛУШКА)")
    else:
        print(f"  🔴 {m} (main.sh ВІДСУТНІЙ)")

# 3. Перевірка папок module_108...150
print(f"\n═══ ПЕРЕВІРКА МОДУЛІВ 108-150 ═══")
for i in range(108, 151):
    found = list((CYBRA / "modules").glob(f"module_{i}_*"))
    if found:
        mod_path = found[0] / "main.sh"
        if mod_path.exists():
            size = mod_path.stat().st_size
            if size > 200:
                print(f"  🟢 [{i}] {found[0].name} ({size} bytes)")
            else:
                print(f"  🟡 [{i}] {found[0].name} ({size} bytes — ЗАГЛУШКА)")
        else:
            print(f"  🔴 [{i}] {found[0].name} (немає main.sh)")
    else:
        print(f"  🔴 [{i}] module_{i}_* (ВІДСУТНІЙ)")
