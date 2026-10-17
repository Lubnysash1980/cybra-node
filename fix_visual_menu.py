#!/usr/bin/env python3
import os, re, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ВИДАЛЕННЯ ФЕЙКОВИХ ПУНКТІВ З ВІЗУАЛЬНОГО МЕНЮ ═══")
text = MENU.read_text()
lines = text.splitlines()
new_lines = []

removed = 0
for line in lines:
    # Шукаємо рядки, які виводять пункти 108-150
    # Формат: printf '  🟢 %s[108]%s ...' або подібне
    m = re.search(r'\[(\d+)\]', line)
    if m:
        num = int(m.group(1))
        if 108 <= num <= 150:
            # Пропускаємо цей рядок (видаляємо)
            removed += 1
            continue
    new_lines.append(line)

MENU.write_text("\n".join(new_lines))
print(f"  [✓] Видалено {removed} рядків з візуального меню")

print("\n═══ 2. КОМІТ У GIT ═══")
run("git add modules/module_19_contract_tui_menu/bin/cybra_menu.sh", cwd=str(CYBIRA))
r = run('git commit -m "fix: remove fake visual menu items 108-150"', cwd=str(CYBIRA))
print(r.stdout)

print("\n[✓] ГОТОВО. Тепер меню показує тільки реальні пункти.")
print("Перевір: ~/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh")
