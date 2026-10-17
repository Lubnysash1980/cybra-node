#!/usr/bin/env python3
import os, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
NODE_PATH = CYBRA / "bin" / "cybra_autonode_cybra"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. СТВОРЕННЯ НОДИ @cybra ═══")
node_content = r'''#!/data/data/com.termux/files/usr/bin/bash
CYBRA_HOME="${HOME}/CYBRA"
NODE_DIR="${CYBRA_HOME}/@cybra"
LOG="${CYBRA_HOME}/logs/evo_node_cybra.log"
mkdir -p "${CYBRA_HOME}/logs"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

cd "$NODE_DIR" || { log "Node: папка @cybra не знайдена"; exit 1; }
log "=== Node @cybra Start ==="

evo_check() {
    local errors=0
    [ -d .git ] || errors=$((errors+1))
    [ -f "index.json" ] || { log "EVO: немає index.json"; errors=$((errors+1)); }
    
    if [ "$errors" -eq 0 ]; then
        log "EVO: 100% — нода @cybra стабільна."
        return 0
    else
        log "EVO: Відхилення! Помилок: $errors"
        return 1
    fi
}

evo_rollback() {
    log "EVO: git reset --hard HEAD..."
    git reset --hard HEAD --quiet 2>/dev/null
    git clean -fd --quiet 2>/dev/null
}

if ! evo_check; then
    evo_rollback
    evo_check
fi
log "=== Node @cybra End ==="
'''
NODE_PATH.write_text(node_content, encoding="utf-8")
os.chmod(NODE_PATH, 0o755)
print(f"  [✓] Створено {NODE_PATH}")

print("\n═══ 2. ПЕРЕЗАПУСК PM2 ═══")
run("pm2 delete all")
run("pm2 start ~/CYBRA/ecosystem.config.js")
run("pm2 save")
r = run("pm2 status")
print(r.stdout)

print("\n═══ 3. КОМІТ У GIT ═══")
run("git add bin/cybra_autonode_cybra", cwd=str(CYBRA))
r = run('git commit -m "fix: restore @cybra node script"', cwd=str(CYBRA))
print(r.stdout)
