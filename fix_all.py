#!/usr/bin/env python3
import os, re, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LIB = CYBRA / "lib" / "cybra_evo_core.sh"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

# ─── 1. СТВОРЮЄМО EVO CORE З НУЛЯ ───
print("═══ 1. СТВОРЕННЯ EVO CORE ═══")
LIB.parent.mkdir(exist_ok=True)

evo_core = r'''#!/data/data/com.termux/files/usr/bin/bash
# cybra_evo_core.sh — Еволюційне ядро (Rollback & Reboot)

CYBRA_HOME="${HOME}/CYBRA"
LOG="${CYBRA_HOME}/logs/evo.log"
mkdir -p "${CYBRA_HOME}/logs"

evo_log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

evo_recover_file() {
    local f="$1"
    evo_log "EVO: відновлення $f..."
    if [ -d "${CYBRA_HOME}/.git" ]; then
        (cd "${CYBRA_HOME}" && git checkout HEAD -- "$f" 2>/dev/null || git checkout origin/main -- "$f" 2>/dev/null)
    fi
    [ -f "$f" ] && return 0 || return 1
}

# Перевірка, чи модуль справжній (не заглушка)
evo_is_real_module() {
    local mod_path="$1"
    if [ ! -f "$mod_path" ]; then
        echo "missing"
        return
    fi
    local size=$(stat -c %s "$mod_path" 2>/dev/null || wc -c < "$mod_path")
    if [ "$size" -lt 1000 ]; then
        echo "stub"
    else
        echo "real"
    fi
}

evo_check() {
    local errors=0

    # 1. Python
    command -v python3 >/dev/null 2>&1 || { evo_log "EVO ERROR: python3"; errors=$((errors+1)); }

    # 2. Git
    if [ -d "${CYBRA_HOME}/.git" ]; then
        (cd "${CYBRA_HOME}" && git status >/dev/null 2>&1) || { evo_log "EVO ERROR: Git"; errors=$((errors+1)); }
    else
        errors=$((errors+1))
    fi

    # 3. Критичні файли
    [ -f "${CYBRA_HOME}/lib/cybra_invoice_lib.sh" ] || evo_recover_file "lib/cybra_invoice_lib.sh" || errors=$((errors+1))
    [ -f "${CYBRA_HOME}/modules/module_19_contract_tui_menu/bin/cybra_menu.sh" ] || evo_recover_file "modules/module_19_contract_tui_menu/bin/cybra_menu.sh" || errors=$((errors+1))

    if [ "$errors" -eq 0 ]; then
        evo_log "EVO: 100% — система в нормі."
        export EVO_STATE_PCT=100
    else
        evo_log "EVO: Відхилення! Помилок: $errors"
        export EVO_STATE_PCT=$((100 - errors * 3))
    fi
}

# ─── ГОЛОВНА ЛОГІКА (ЗАМОК 100%) ───
evo_enforce_100() {
    if [ "${EVO_STATE_PCT:-0}" -ne 100 ]; then
        echo -e "\033[91m🛑 EVO SECURITY: Система не на 100% (поточний: ${EVO_STATE_PCT}%).\033[0m"
        echo -e "\033[93m🔄 Запуск автоматичного відкату...\033[0m"
        evo_hard_rollback
        exit 1
    fi
}

evo_hard_rollback() {
    evo_log "EVO CRITICAL: HARD ROLLBACK."
    if [ -d "${CYBRA_HOME}/.git" ]; then
        cd "${CYBRA_HOME}" || exit 1
        git fetch origin main --quiet 2>/dev/null
        git reset --hard origin/main --quiet 2>/dev/null
        git clean -fd --quiet 2>/dev/null
        evo_log "EVO: Відкат завершено."
    fi
}

# Виконання
evo_check
'''

LIB.write_text(evo_core)
os.chmod(LIB, 0o755)
print("  [✓] Створено cybra_evo_core.sh")

# ─── 2. КОМЕНТУЄМО ФЕЙКОВІ МОДУЛІ В МЕНЮ ───
print("\n═══ 2. ПРИБИРАННЯ ФЕЙКОВИХ МОДУЛІВ З МЕНЮ ═══")
menu_content = MENU.read_text()

commented_count = 0
for i in range(108, 151):
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
        if pattern.search(menu_content):
            menu_content = pattern.sub(r'# \1', menu_content)
            commented_count += 1
            print(f"  [✓] Пункт {i} закоментовано (заглушка, {size} байт)")

MENU.write_text(menu_content)
print(f"  Всього закоментовано: {commented_count}")

# ─── 3. КОМІТ У GIT ───
print("\n═══ 3. КОМІТ У GIT ═══")
run("git add lib/cybra_evo_core.sh modules/module_19_contract_tui_menu/bin/cybra_menu.sh", cwd=str(CYBRA))
r = run('git commit -m "fix: EVO core restored, fake modules hidden"', cwd=str(CYBRA))
print(r.stdout)

print("\n[✓] ГОТОВО.")
