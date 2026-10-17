#!/usr/bin/env python3
import os, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LIB = CYBRA / "lib" / "cybra_evo_core.sh"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ОНОВЛЕННЯ EVO CORE ═══")
# Додаємо функцію, яка перевіряє модуль на "справжність"
evo_core_add = r'''
# ─── EVO: Перевірка модулів на справжність ───
evo_is_real_module() {
    local mod_path="$1"
    if [ ! -f "$mod_path" ]; then
        echo "missing"
        return
    fi
    local size=$(stat -c %s "$mod_path" 2>/dev/null || wc -c < "$mod_path")
    if [ "$size" -lt 1000 ]; then
        echo "stub" # Заглушка
    else
        echo "real" # Справжній модуль
    fi
}

# Перевіряє всі модулі 108-150 і повертає список "реальних"
evo_list_real_modules() {
    local list=""
    for i in $(seq 108 150); do
        local dir=$(ls -d "$CYBRA_HOME/modules/module_${i}_"* 2>/dev/null | head -1)
        if [ -n "$dir" ]; then
            local main="$dir/main.sh"
            local status=$(evo_is_real_module "$main")
            if [ "$status" = "real" ]; then
                list="$list $i"
            fi
        fi
    done
    echo "$list"
}
'''
# Додаємо в кінець файлу, якщо ще немає
content = LIB.read_text()
if "evo_is_real_module" not in content:
    LIB.write_text(content + evo_core_add)
    print("  [✓] evo_core.sh оновлено (додано перевірку модулів)")
else:
    print("  [i] evo_core.sh вже має перевірку")

print("\n═══ 2. ОНОВЛЕННЯ МЕНЮ ═══")
# У меню додаємо динамічне приховування фейкових пунктів
# Знаходимо функцію print_menu і додаємо перевірку перед виводом 108-150
menu_content = MENU.read_text()

# Замінюємо жорсткий вивід на перевірку
# (Це складно зробити регуляркою, тому просто додамо коментар)
# Насправді, найпростіше — це закоментувати всі фейкові рядки в case,
# але тільки ті, що дійсно заглушки.

# Знаходимо рядки в case для 108-150
import re
for i in range(108, 151):
    # Знаходимо папку модуля
    mod_dirs = list((CYBRA / "modules").glob(f"module_{i}_*"))
    if not mod_dirs:
        continue
    main_sh = mod_dirs[0] / "main.sh"
    if not main_sh.exists():
        continue
    size = main_sh.stat().st_size
    if size < 1000:
        # Це заглушка — коментуємо виклик у case
        pattern = re.compile(rf'^(\s*{i}\)\s+bash\s+".*")$', re.MULTILINE)
        menu_content = pattern.sub(r'# \1', menu_content)
        print(f"  [✓] Пункт {i} закоментовано (заглушка, {size} байт)")

MENU.write_text(menu_content)
print("  [✓] Меню оновлено")

print("\n═══ 3. КОМІТ У GIT ═══")
run("git add lib/cybra_evo_core.sh modules/module_19_contract_tui_menu/bin/cybra_menu.sh", cwd=str(CYBIRA))
r = run('git commit -m "feat: EVO hides stub modules (size < 1000 bytes)"', cwd=str(CYBIRA))
print(r.stdout)

print("\n[✓] ГОТОВО. Тепер EVO знає, що модулі 108-150 — це заглушки, і ховає їх з меню.")
