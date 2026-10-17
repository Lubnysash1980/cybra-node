#!/usr/bin/env python3
import os, subprocess, json
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
NODE_DIR = CYBRA / "@cybra"
BIN = CYBRA / "bin"
BIN.mkdir(exist_ok=True)

print("═══ 1. СТВОРЕННЯ НОДИ @cybra ═══")
NODE_DIR.mkdir(parents=True, exist_ok=True)

# Скрипт ноди (працює всередині @cybra)
autonode_sh = r'''#!/data/data/com.termux/files/usr/bin/bash
# cybra_autonode — нода для репозиторію @cybra

CYBRA_HOME="${HOME}/CYBRA"
NODE_DIR="${CYBRA_HOME}/@cybra"
LOG="${CYBRA_HOME}/logs/autonode.log"
EVO_LOG="${CYBRA_HOME}/logs/evo_node.log"

mkdir -p "${CYBRA_HOME}/logs"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }
evo_log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$EVO_LOG"; }

# Переходимо в папку @cybra
cd "$NODE_DIR" || { log "Autonode: папка $NODE_DIR не знайдена!"; exit 1; }
log "=== Autonode @cybra Start ==="

# 1. Ініціалізація Git (якщо немає)
if [ ! -d .git ]; then
    log "Autonode: Ініціалізація Git у @cybra..."
    git init -b main
    git remote add origin https://github.com/Lubnysash1980/cybra-at-node.git
    git pull origin main --rebase 2>/dev/null || true
fi

# 2. EVO Перевірка
evo_check() {
    local errors=0
    [ -d .git ] || { evo_log "EVO: немає .git"; errors=$((errors+1)); }
    command -v python3 >/dev/null 2>&1 || { evo_log "EVO: python3 зник"; errors=$((errors+1)); }
    
    # Перевірка індексів
    [ -f "index.json" ] || { evo_log "EVO: немає index.json"; errors=$((errors+1)); }
    [ -d "modules" ] || { evo_log "EVO: немає папки modules"; errors=$((errors+1)); }

    if [ "$errors" -eq 0 ]; then
        evo_log "EVO: 100% — нода стабільна."
        return 0
    else
        evo_log "EVO: Відхилення! Помилок: $errors. Запуск ROLLBACK."
        return 1
    fi
}

# 3. Відкат (якщо EVO знайшов помилку)
evo_rollback() {
    evo_log "EVO: git reset --hard origin/main у @cybra..."
    if [ -d .git ]; then
        git fetch origin main --quiet 2>/dev/null
        git reset --hard origin/main --quiet 2>/dev/null
        git clean -fd --quiet 2>/dev/null
    fi
}

# 4. Синхронізація
sync_git() {
    if [ -d .git ]; then
        git pull origin main --rebase -q 2>&1 | tee -a "$LOG" || log "Autonode: pull failed"
        if [ -n "$(git status --porcelain)" ]; then
            log "Autonode: коміт змін..."
            git add -A
            git commit -m "auto: @cybra sync $(date -u +"%Y-%m-%dT%H:%M:%SZ")" -q
            git push origin main -q 2>&1 | tee -a "$LOG" || log "Autonode: push failed"
        else
            log "Autonode: немає змін для коміту."
        fi
    fi
}

# ─── ВИКОНАННЯ ───
if ! evo_check; then
    evo_rollback
    if evo_check; then
        log "Autonode: EVO відновив ноду."
    else
        log "Autonode: EVO не зміг відновити ноду."
    fi
fi

sync_git
log "=== Autonode @cybra End ==="
'''

autonode_path = BIN / "cybra_autonode_cybra"
autonode_path.write_text(autonode_sh, encoding="utf-8")
os.chmod(autonode_path, 0o755)
print(f"[✓] Створено {autonode_path}")

# ─── 2. Оновлюємо ecosystem.config.js для PM2 ───
print("\n═══ 2. ОНОВЛЕННЯ PM2 ═══")
eco_path = CYBRA / "ecosystem.config.js"
eco_content = """module.exports = {
  apps: [
    {
      name: "cybra-autonode-at",
      script: "/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_cybra",
      interpreter: "bash",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true,
      cron_restart: "*/15 * * * *"
    }
  ]
};
"""
eco_path.write_text(eco_content, encoding="utf-8")
print("[✓] ecosystem.config.js оновлено для @cybra")

# ─── 3. Перевірка Git ───
print("\n═══ 3. GIT У @cybra ═══")
if not (NODE_DIR / ".git").exists():
    print("  [!] Git не ініціалізовано. Ініціалізуємо...")
    subprocess.run(["git", "init", "-b", "main"], cwd=str(NODE_DIR), capture_output=True)
    subprocess.run(["git", "remote", "add", "origin", "https://github.com/Lubnysash1980/cybra-at-node.git"], cwd=str(NODE_DIR), capture_output=True)
    print("  [✓] Git ініціалізовано з remote origin")
else:
    print("  [✓] Git вже ініціалізовано")

print("\n[✓] ГОТОВО.")
print("Запусти ноду: ~/CYBRA/bin/cybra_autonode_cybra")
print("Або через PM2: pm2 start ~/CYBRA/ecosystem.config.js")
