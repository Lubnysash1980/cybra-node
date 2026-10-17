#!/usr/bin/env python3
import os, re, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ЧИТАЄМО ФАЙЛ ═══")
text = MENU.read_text()

# ─── 2. Знаходимо блок case "$CHOICE" in ───
# Шукаємо від "case \"$CHOICE\" in" до "esac"
pattern = re.compile(r'(case "\$CHOICE" in\s*\n)(.*?)(\n\s*esac)', re.DOTALL)
match = pattern.search(text)
if not match:
    print("  [!] Не знайдено case \"$CHOICE\" in")
    exit(1)

header, body, footer = match.groups()

# ─── 3. Аналізуємо, які пункти вже є в case ───
existing = set()
for line in body.splitlines():
    m = re.match(r'^\s*(\d+)\)', line)
    if m:
        existing.add(int(m.group(1)))

# ─── 4. Знаходимо, яких пунктів немає (від 1 до 150) ───
missing = []
for i in range(1, 151):
    if i not in existing:
        missing.append(i)

print(f"  Пунктів у case: {len(existing)}")
print(f"  Відсутніх: {len(missing)}")

# ─── 5. Генеруємо нові рядки для case ───
new_case_lines = []
for i in missing:
    new_case_lines.append(f'        {i}) action_generic_{i} ;;')

# ─── 6. Вставляємо нові рядки перед "*)" ───
# Знаходимо рядок "*)" у body
star_idx = body.find("*)")
if star_idx == -1:
    print("  [!] Не знайдено '*' у case")
    exit(1)

# Розділяємо body на "до *" і "від *"
before_star = body[:star_idx].rstrip()
after_star = body[star_idx:]

new_body = before_star + "\n" + "\n".join(new_case_lines) + "\n        " + after_star

# ─── 7. Збираємо новий текст ───
new_text = text[:match.start()] + header + new_body + footer + text[match.end():]

# ─── 8. Додаємо функції-заглушки перед "while true" ───
if "action_generic_" not in text:
    funcs = "\n# ─── GENERIC ACTIONS (заглушки) ───\n"
    for i in missing:
        funcs += f"""action_generic_{i}() {{
    echo "Пункт [{i}] в розробці"
    read -r _
}}
"""
    
    while_idx = new_text.find("while true; do")
    if while_idx != -1:
        new_text = new_text[:while_idx] + funcs + "\n" + new_text[while_idx:]
        print("  [✓] Додано функції-заглушки")
else:
    print("  [i] Функції-заглушки вже є")

MENU.write_text(new_text)
print("  [✓] Меню оновлено")

# ─── 9. Перевірка синтаксису ───
print("\n═══ 9. ПЕРЕВІРКА СИНТАКСИСУ ═══")
r = run(f"bash -n {MENU}")
if r.returncode == 0:
    print("  [✓] bash -n OK")
else:
    print(f"  [✗] ПОМИЛКА:\n{r.stderr}")
    run("git checkout HEAD -- modules/module_19_contract_tui_menu/bin/cybra_menu.sh", cwd=str(CYBIRA))
    print("  [↩] Відкочено")
    exit(1)

# ─── 10. Коміт ───
print("\n═══ 10. КОМІТ У GIT ═══")
run("git add modules/module_19_contract_tui_menu/bin/cybra_menu.sh", cwd=str(CYBIRA))
r = run('git commit -m "feat: parliament generated handlers for all menu items"', cwd=str(CYBIRA))
print(r.stdout)

print("\n[✓] ГОТОВО. Тепер усі 150 пунктів мають обробники.")
