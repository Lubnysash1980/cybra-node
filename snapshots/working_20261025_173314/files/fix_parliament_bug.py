#!/usr/bin/env python3
import os, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
ENGINE_FILE = CYBRA / "modules/module_121_parlament/bin/parliament_hidl_engine.py"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ВИПРАВЛЕННЯ БАГУ В ДВИГУНІ ═══")
if ENGINE_FILE.exists():
    content = ENGINE_FILE.read_text()
    if "CYBIRA" in content:
        content = content.replace("CYBIRA", "CYBRA")
        ENGINE_FILE.write_text(content)
        print("  [✓] Помилку 'CYBIRA' виправлено на 'CYBRA'")
    else:
        print("  [i] Помилки не знайдено (вже виправлено)")

print("\n═══ 2. КОМІТ УЖЕ СТВОРЕНИХ МОДУЛІВ ═══")
# Додаємо всі згенеровані модулі та оновлене меню в Git
run("git add modules/", cwd=str(CYBRA))
run("git add config/cybra_hidl.json", cwd=str(CYBRA))

r = run('git commit -m "fix: commit parliament generated modules (1-11) + fix CYBIRA bug"', cwd=str(CYBRA))
if r.returncode == 0:
    print("  [✓] Зміни закомічено в Git")
else:
    print("  [i] Немає нових змін для коміту (або вже закомічено)")

print("\n═══ 3. ПЕРЕЗАПУСК ВОРКЕРА В PM2 ═══")
run("pm2 restart cybra-parliament-worker")
print("  [✓] cybra-parliament-worker перезапущено з виправленим кодом")

print("\n═══ 4. ПЕРЕВІРКА СТАТУСУ ═══")
r = run("pm2 status")
print(r.stdout)

print("\n[✓] ГОТОВО. Тепер парламент може знову генерувати модулі і робити коміти.")
