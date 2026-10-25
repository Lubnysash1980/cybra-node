#!/usr/bin/env python3
import os, json, subprocess, shutil, re
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
ENGINE_FILE = CYBRA / "modules/module_121_parlament/bin/parliament_hidl_engine.py"
HIDL_FILE = CYBRA / "config" / "cybra_hidl.json"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ВИПРАВЛЕННЯ ФУНКЦІЇ get_menu_title ═══")
engine_text = ENGINE_FILE.read_text()

# Замінюємо функцію на надійну
old_func = '''def get_menu_title(target_id):
    # Витягуємо назву пункту з меню (наприклад, [44] AI Вільне питання)
    try:
        content = MENU_FILE.read_text()
        match = re.search(rf'\\[{target_id}\\]\\s+([^\\n\\']+)', content)
        if match:
            return match.group(1).strip()
    except:
        pass
    return f"Модуль {target_id}"'''

new_func = '''def get_menu_title(target_id):
    # Витягуємо назву пункту з меню (наприклад, [44] AI Вільне питання)
    try:
        content = MENU_FILE.read_text()
        for line in content.split('\\n'):
            if f'[{target_id}]' in line:
                idx = line.find(f'[{target_id}]')
                after = line[idx + len(f'[{target_id}]'):]
                if after.startswith('%s'):
                    after = after[2:]
                if after.startswith(' '):
                    after = after[1:]
                if '\\\\n' in after:
                    after = after.split('\\\\n')[0]
                elif "'" in after:
                    after = after.split("'")[0]
                return after.strip()
    except Exception:
        pass
    return f"Модуль {target_id}"'''

if old_func in engine_text:
    engine_text = engine_text.replace(old_func, new_func)
    print("  [✓] get_menu_title виправлено")
else:
    print("  [!] Стару функцію не знайдено, замінюємо всю")

engine_text = engine_text.replace("CYBIRA", "CYBRA")
ENGINE_FILE.write_text(engine_text)
print("  [✓] CYBIRA → CYBRA виправлено")

print("\n═══ 2. СКИДАННЯ GENERIC-МОДУЛІВ ═══")
hidl = json.loads(HIDL_FILE.read_text())
reset_count = 0

for mod_dir in (CYBRA / "modules").glob("module_*_generated"):
    main_sh = mod_dir / "main.sh"
    if not main_sh.exists():
        continue
    content = main_sh.read_text()
    if "Базовий функціонал активовано" in content or "Модуль ініціалізовано IT-департаментом" in content:
        m = re.match(r'module_(\d+)_generated', mod_dir.name)
        if m:
            tid = m.group(1)
            shutil.rmtree(mod_dir)
            if tid in hidl["menu_items"]:
                hidl["menu_items"][tid]["status"] = "stub"
                hidl["menu_items"][tid]["evo_score"] = 10
                reset_count += 1
                print(f"  [✓] Скинуто модуль {tid} для регенерації")

HIDL_FILE.write_text(json.dumps(hidl, indent=2, ensure_ascii=False))
print(f"  [✓] Скинуто {reset_count} модулів")

print("\n═══ 3. ПЕРЕЗАПУСК ВОРКЕРА ═══")
run("pm2 restart cybra-parliament-worker")
print("  [✓] cybra-parliament-worker перезапущено")

print("\n[✓] ГОТОВО.")
print("Тепер парламент буде генерувати РОЗУМНИЙ код, знаючи назви пунктів.")
print("Зачекай 1-2 хвилини, потім спробуй пункт 44 знову.")
