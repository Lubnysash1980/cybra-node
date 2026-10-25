#!/usr/bin/env python3
import os, json, subprocess, shutil
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
BIN = CYBRA / "bin"
HIDL_FILE = CYBRA / "config" / "cybra_hidl.json"
MENU_FILE = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
ENGINE_FILE = CYBRA / "modules/module_121_parlament/bin/parliament_hidl_engine.py"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ВИПРАВЛЕННЯ EVO-НОД (ВИДАЛЕННЯ git clean) ═══")
# Переписуємо ноди, щоб вони не видаляли нові файли
for node_name in ["cybra_autonode_main", "cybra_autonode_cybra"]:
    node_path = BIN / node_name
    if not node_path.exists(): continue
    content = node_path.read_text()
    
    # Видаляємо небезпечний git clean -fd
    if "git clean -fd" in content:
        content = content.replace("git clean -fd --quiet 2>/dev/null", "# git clean -fd (вимкнено, щоб не видаляти модулі парламенту)")
        node_path.write_text(content)
        print(f"  [✓] {node_name}: видалено 'git clean -fd'")

print("\n═══ 2. СКИДАННЯ HIDL ДЛЯ ВИДАЛЕНИХ МОДУЛІВ ═══")
hidl = json.loads(HIDL_FILE.read_text())
reset_count = 0

for i in range(1, 151):
    mod_dir = CYBRA / "modules" / f"module_{i}_generated"
    main_sh = mod_dir / "main.sh"
    
    if not main_sh.exists():
        hidl["menu_items"][str(i)]["status"] = "stub"
        hidl["menu_items"][str(i)]["evo_score"] = 10
        
        # Також повертаємо заглушку в меню
        menu_content = MENU_FILE.read_text()
        old_case = f'{i}) bash "$HOME/CYBRA/modules/module_{i}_generated/main.sh" ;;'
        new_case = f"{i}) action_generic_{i} ;;"
        if old_case in menu_content:
            menu_content = menu_content.replace(old_case, new_case)
            MENU_FILE.write_text(menu_content)
        
        reset_count += 1

HIDL_FILE.write_text(json.dumps(hidl, indent=2, ensure_ascii=False))
print(f"  [✓] Скинуто {reset_count} модулів назад у статус 'stub'")

print("\n═══ 3. ПЕРЕВІРКА ДВИГУНА ПАРЛАМЕНТУ ═══")
if ENGINE_FILE.exists():
    content = ENGINE_FILE.read_text()
    if "CYBIRA" in content:
        content = content.replace("CYBIRA", "CYBRA")
        ENGINE_FILE.write_text(content)
        print("  [✓] Виправлено CYBIRA -> CYBRA в двигуні")

print("\n═══ 4. ПЕРЕЗАПУСК PM2 ═══")
run("pm2 delete all")
run("pm2 start ~/CYBRA/ecosystem.config.js")
run("pm2 save")
r = run("pm2 status")
print(r.stdout)

print("\n[✓] ГОТОВО.")
print("Тепер EVO не буде видаляти файли парламенту.")
print("Парламент почне генерувати їх заново, і вони збережуться.")
