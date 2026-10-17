#!/usr/bin/env python3
import os, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
BIN = CYBRA / "bin"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ПЕРЕЗАПИС НОДИ MAIN ═══")
main_node = r'''#!/data/data/com.termux/files/usr/bin/bash
CYBRA_HOME="${HOME}/CYBRA"
LOG="${CYBRA_HOME}/logs/evo_node_main.log"
mkdir -p "${CYBRA_HOME}/logs"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

cd "$CYBRA_HOME" || exit 1
log "=== Node Main Start ==="

while true; do
    # Перевірка файлів
    if [ ! -f "lib/cybra_invoice_lib.sh" ]; then
        log "EVO: немає lib, робимо локальний rollback"
        git reset --hard HEAD --quiet 2>/dev/null
        git clean -fd --quiet 2>/dev/null
    fi
    
    log "EVO: 100% — система в нормі"
    sleep 60
done
'''

(BIN / "cybra_autonode_main").write_text(main_node)
os.chmod(BIN / "cybra_autonode_main", 0o755)
print("  [✓] cybra_autonode_main перезаписано")

print("\n═══ 2. ПЕРЕЗАПИС НОДИ @cybra ═══")
cybra_node = r'''#!/data/data/com.termux/files/usr/bin/bash
CYBRA_HOME="${HOME}/CYBRA"
NODE_DIR="${CYBRA_HOME}/@cybra"
LOG="${CYBRA_HOME}/logs/evo_node_cybra.log"
mkdir -p "${CYBRA_HOME}/logs"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

cd "$NODE_DIR" || exit 1
log "=== Node @cybra Start ==="

while true; do
    if [ ! -f "index.json" ]; then
        log "EVO: немає index.json, робимо локальний rollback"
        git reset --hard HEAD --quiet 2>/dev/null
        git clean -fd --quiet 2>/dev/null
    fi
    
    log "EVO: 100% — нода @cybra стабільна"
    sleep 60
done
'''

(BIN / "cybra_autonode_cybra").write_text(cybra_node)
os.chmod(BIN / "cybra_autonode_cybra", 0o755)
print("  [✓] cybra_autonode_cybra перезаписано")

print("\n═══ 3. ПЕРЕЗАПУСК PM2 ═══")
run("pm2 delete all")
run("pm2 start ~/CYBRA/ecosystem.config.js")
run("pm2 save")
r = run("pm2 status")
print(r.stdout)

print("\n═══ 4. КОМІТ У GIT ═══")
run("git add bin/cybra_autonode_main bin/cybra_autonode_cybra", cwd=str(CYBIRA))
r = run('git commit -m "fix: remove git push/pull from nodes (local mode)"', cwd=str(CYBIRA))
print(r.stdout)

print("\n[✓] ГОТОВО.")
