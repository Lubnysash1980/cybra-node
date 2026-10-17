#!/usr/bin/env python3
import os, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ЧИТАЄМО ФАЙЛ ═══")
lines = MENU.read_text().splitlines()
print(f"  Всього рядків: {len(lines)}")

print("\n═══ 2. ШУКАЄМО БЛОК NODE/HASH ═══")
start_idx = None
end_idx = None

for i, line in enumerate(lines):
    if "─── NODE/HASH ───" in line:
        start_idx = i
        break

if start_idx is None:
    print("  [!] Блок NODE/HASH не знайдено. Можливо, вже видалено.")
    exit(0)

# Шукаємо кінець функції print_menu (закриваюча дужка на початку рядка)
for i in range(start_idx, len(lines)):
    if lines[i].strip() == "}":
        end_idx = i
        break

if end_idx is None:
    print("  [!] Не знайдено кінець функції print_menu")
    exit(1)

print(f"  Блок NODE/HASH: рядки {start_idx+1} - {end_idx}")
print(f"  Буде видалено {end_idx - start_idx} рядків")

# ─── 3. Вирізаємо блок і вставляємо фінальний вивід ───
# Залишаємо все до start_idx, потім додаємо фінальний вивід і закриваючу дужку
new_lines = lines[:start_idx]

# Додаємо фінальний вивід (як було в оригіналі)
new_lines.append("")
new_lines.append("    printf '%s\\n' \"  ${C_GREY}🟢 ready  🟡 warning  🔴 error${C_RESET}\"")
new_lines.append("    printf '\\n'")
new_lines.append("    printf '  %s[0]%s  Вихід\\n\\n' \"$C_BOLD\" \"$C_RESET\"")
new_lines.append("}")

# Додаємо все після end_idx (там має бути while true і т.д.)
new_lines.extend(lines[end_idx + 1:])

MENU.write_text("\n".join(new_lines))
print(f"  [✓] Вирізано фейкові пункти. Новий розмір: {len(new_lines)} рядків")

print("\n═══ 4. ПЕРЕВІРКА СИНТАКСИСУ ═══")
r = run(f"bash -n {MENU}")
if r.returncode == 0:
    print("  [✓] bash -n OK")
else:
    print(f"  [✗] bash -n ПОМИЛКА:\n{r.stderr}")
    exit(1)

print("\n═══ 5. КОМІТ У GIT ═══")
run("git add modules/module_19_contract_tui_menu/bin/cybra_menu.sh", cwd=str(CYBIRA))
r = run('git commit -m "fix: remove fake menu items correctly"', cwd=str(CYBIRA))
print(r.stdout)

print("\n[✓] ГОТОВО. Меню тепер закінчується на [107] Autopilot.")
