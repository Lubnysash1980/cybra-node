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

# ─── 2. Знаходимо початок блоку NODE/HASH ───
start_idx = None
for i, line in enumerate(lines):
    if "─── NODE/HASH ───" in line:
        start_idx = i
        break

if start_idx is None:
    print("  [!] Блок NODE/HASH не знайдено.")
    exit(0)

# ─── 3. Знаходимо кінець функції print_menu (шукаємо `}` перед `while true`) ───
# Йдемо від start_idx вниз, шукаємо рядок, який починається з `while`
while_idx = None
for i in range(start_idx, len(lines)):
    if lines[i].strip().startswith("while "):
        while_idx = i
        break

if while_idx is None:
    print("  [!] Не знайдено 'while' цикл")
    exit(1)

# Тепер йдемо назад від while_idx, шукаємо `}` — це кінець print_menu
end_idx = None
for i in range(while_idx - 1, start_idx, -1):
    if lines[i].strip() == "}":
        end_idx = i
        break

if end_idx is None:
    print("  [!] Не знайдено '}' перед while")
    exit(1)

print(f"  Блок NODE/HASH: рядки {start_idx+1} - {end_idx}")
print(f"  Буде видалено {end_idx - start_idx} рядків")

# ─── 4. Збираємо новий файл ───
# Беремо все до start_idx
new_lines = lines[:start_idx]

# Додаємо фінальний вивід (як було)
new_lines.append("    printf '\\n'")
new_lines.append("    printf '%s\\n' \"  ${C_GREY}🟢 ready  🟡 warning  🔴 error${C_RESET}\"")
new_lines.append("    printf '\\n'")
new_lines.append("    printf '  %s[0]%s  Вихід\\n\\n' \"$C_BOLD\" \"$C_RESET\"")
new_lines.append("}")

# Додаємо все від while_idx (включно) до кінця
new_lines.extend(lines[while_idx:])

MENU.write_text("\n".join(new_lines))
print(f"  [✓] Вирізано фейкові пункти. Новий розмір: {len(new_lines)} рядків")

# ─── 5. Перевірка синтаксису ───
print("\n═══ 5. ПЕРЕВІРКА СИНТАКСИСУ ═══")
r = run(f"bash -n {MENU}")
if r.returncode == 0:
    print("  [✓] bash -n OK")
else:
    print(f"  [✗] bash -n ПОМИЛКА:\n{r.stderr}")
    print("  [!] Відкат...")
    # Відкат через git
    run("git checkout HEAD -- modules/module_19_contract_tui_menu/bin/cybra_menu.sh", cwd=str(CYBIRA))
    print("  [↩] Відкочено")
    exit(1)

# ─── 6. Коміт ───
print("\n═══ 6. КОМІТ У GIT ═══")
run("git add modules/module_19_contract_tui_menu/bin/cybra_menu.sh", cwd=str(CYBIRA))
r = run('git commit -m "fix: correctly remove fake menu items"', cwd=str(CYBIRA))
print(r.stdout)

print("\n[✓] ГОТОВО. Меню тепер закінчується на [107].")
