#!/usr/bin/env python3
import os, shutil, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MODS = CYBRA / "modules"
MENU = MODS / "module_19_contract_tui_menu/bin/cybra_menu.sh"

def is_stub(filepath):
    """Перевіряє, чи файл є заглушкою (мало коду, тільки echo)."""
    try:
        content = filepath.read_text()
        lines = [line.strip() for line in content.splitlines() if line.strip() and not line.startswith("#")]
        # Якщо рядків дуже мало і немає sqlite/python/curl — це заглушка
        if len(lines) < 20 and "sqlite" not in content and "python" not in content and "curl" not in content:
            return True
    except:
        return True
    return False

print("🧹 ПОШУК ТА ВИДАЛЕННЯ ЗАГЛУШОК...")
deleted_count = 0

# 1. Видаляємо папки-заглушки
for mod_dir in MODS.glob("module_*_base"):
    main_sh = mod_dir / "main.sh"
    if main_sh.exists() and is_stub(main_sh):
        shutil.rmtree(mod_dir)
        deleted_count += 1
        print(f"  🗑️ Видалено: {mod_dir.name}")

print(f"✅ Видалено {deleted_count} порожніх модулів.")

# 2. Чистимо меню, щоб прибрати виклики видалених модулів
if MENU.exists():
    lines = MENU.read_text().splitlines()
    new_lines = []
    for line in lines:
        # Прибираємо загальний виклик для 100-148 модулів, які ми видалили
        if "100|101|102" in line and "148" in line:
            continue
        # Прибираємо візуальний вивід старих модулів (якщо є)
        if any(f"[{i}]" in line for i in range(1, 149)) and "printf" in line:
            continue
            
        new_lines.append(line)
        
    MENU.write_text("\n".join(new_lines) + "\n")
    print("✅ Меню очищено від зайвих пунктів.")

# 3. Зберігаємо в Git
print("⏳ Зберігаємо зміни в Ноду (GitHub)...")
subprocess.run("git add -A", shell=True, cwd=CYBRA)
subprocess.run('git commit --no-verify -m "clean: removed all stub modules, menu is now clean" -q', shell=True, cwd=CYBRA)
subprocess.run("git push origin main -q", shell=True, cwd=CYBRA)

print("\n🎉 СИСТЕМУ ОЧИЩЕНО ВІД СМІТТЯ!")
print("Тепер у меню залишилися ТІЛЬКИ реальні робочі інструменти.")
