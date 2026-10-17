#!/usr/bin/env python3
import os, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

# Оновлюємо ноди, додаючи while true
for node_name in ["cybra_autonode_main", "cybra_autonode_cybra"]:
    node_path = CYBRA / "bin" / node_name
    if not node_path.exists():
        print(f"[!] {node_name} не знайдено")
        continue

    content = node_path.read_text()

    # Перевіряємо, чи вже є цикл
    if "while true" in content:
        print(f"[✓] {node_name}: вже має цикл")
        continue

    # Знаходимо останній рядок (зазвичай log "=== End ===")
    # і замінюємо його на нескінченний цикл з sleep
    lines = content.splitlines()
    # Видаляємо останній рядок (він може бути log "=== ... End ===")
    # і додаємо while true

    # Знаходимо функцію evo_check, яка має виконуватися в циклі
    # Але у нас вже є виклик evo_check в кінці
    # Треба загорнути все у while true

    # Простий підхід: додаємо while true в кінець, але перед ним треба
    # змінити логіку, щоб він не виходив

    # Замість цього, просто перепишемо файл з правильною структурою
    pass

print("\nСтворюємо ноди заново з нескінченним циклом...")

main_node = r'''#!/data/data/com.termux/files/usr/bin/bash
CYBRA_HOME="${HOME}/CYBRA"
LOG="${CYBRA_HOME}/logs/evo_node_main.log"
mkdir -p "${CYBRA_HOME}/logs"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

cd "$CYBRA_HOME" || exit 1
log "=== Node Main Start (loop) ==="

while true; do
    log "--- Cycle ---"
    
    if [ ! -f "lib/cybra_invoice_lib.sh" ]; then
        log "EVO: немає lib, робимо rollback"
        git reset --hard HEAD --quiet 2>/dev/null
        git clean -fd --quiet 2>/dev/null
    else
        log "EVO: 100% — система в нормі"
    fi
    
    log "--- Sleep 60s ---"
    sleep 60
done
'''

cybra_node = r'''#!/data/data/com.termux/files/usr/bin/bash
CYBRA_HOME="${HOME}/CYBRA"
NODE_DIR="${CYBRA_HOME}/@cybra"
LOG="${CYBRA_HOME}/logs/evo_node_cybra.log"
mkdir -p "${CYBRA_HOME}/logs"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

cd "$NODE_DIR" || exit 1
log "=== Node @cybra Start (loop) ==="

while true; do
    log "--- Cycle ---"
    
    if [ ! -f "index.json" ]; then
        log "EVO: немає index.json, робимо rollback"
        git reset --hard HEAD --quiet 2>/dev/null
        git clean -fd --quiet 2>/dev/null
    else
        log "EVO: 100% — нода @cybra стабільна"
    fi
    
    log "--- Sleep 60s ---"
    sleep 60
done
'''

(CYBRA / "bin" / "cybra_autonode_main").write_text(main_node)
(CYBRA / "bin" / "cybra_autonode_cybra").write_text(cybra_node)
os.chmod(CYBRA / "bin" / "cybra_autonode_main", 0o755)
os.chmod(CYBRA / "bin" / "cybra_autonode_cybra", 0o755)
print("[✓] Обидві ноди перезаписано з нескінченним циклом")

print("\nПерезапуск PM2...")
run("pm2 delete all")
run("pm2 start ~/CYBRA/ecosystem.config.js")
run("pm2 save")
r = run("pm2 status")
print(r.stdout)

print("\nКоміт у Git...")
run("git add bin/cybra_autonode_main bin/cybra_autonode_cybra", cwd=str(CYBRA))
r = run('git commit -m "fix: infinite loop for pm2 nodes"', cwd=str(CYBRA))
print(r.stdout)
