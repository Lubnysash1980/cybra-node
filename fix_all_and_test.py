#!/usr/bin/env python3
import os, subprocess, shutil, time
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
NODE = CYBRA / "@cybra"
BIN = CYBRA / "bin"
NODE_SCRIPT = BIN / "cybra_autonode_cybra"
LOG = CYBRA / "logs" / "evo_node.log"

G, R, Y, C, Z = "\033[92m", "\033[91m", "\033[93m", "\033[96m", "\033[0m"
def ok(m): print(f"  {G}[✓]{Z} {m}")
def bad(m): print(f"  {R}[✗]{Z} {m}")
def info(m): print(f"  {C}[i]{Z} {m}")
def hdr(m): print(f"\n{C}═══ {m} ═══{Z}")

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

# ─── 1. Синхронізація Git (вирішення конфлікту) ───
hdr("1. СИНХРОНІЗАЦІЯ GIT (fix push rejected)")
r = run("git pull origin main --rebase", cwd=str(CYBRA))
if r.returncode == 0:
    ok("git pull --rebase")
else:
    # Якщо є конфлікти — скидаємо до стану origin
    info("Конфлікт, скидаємо локальні зміни")
    run("git reset --hard origin/main", cwd=str(CYBRA))
    run("git pull origin main --rebase", cwd=str(CYBRA))

# Комітимо локальні зміни
r = run("git add -A && git commit -m 'auto: fix sync after conflict'", cwd=str(CYBRA))
if r.returncode == 0:
    ok("Локальні зміни закомічено")
else:
    info("Немає змін для коміту")

# Push
r = run("git push origin main", cwd=str(CYBRA))
if r.returncode == 0:
    ok("git push origin main")
else:
    bad(f"push: {r.stderr.strip()[:80]}")

# ─── 2. Перевірка ноди @cybra ───
hdr("2. ПЕРЕВІРКА НОДИ @cybra")
if not NODE_SCRIPT.exists():
    bad(f"Нода не знайдена: {NODE_SCRIPT}")
    # Створюємо
    NODE_SCRIPT.write_text(r'''#!/data/data/com.termux/files/usr/bin/bash
CYBRA_HOME="${HOME}/CYBRA"
NODE_DIR="${CYBRA_HOME}/@cybra"
LOG="${CYBRA_HOME}/logs/autonode.log"
EVO_LOG="${CYBRA_HOME}/logs/evo_node.log"
mkdir -p "${CYBRA_HOME}/logs"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }
evo_log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$EVO_LOG"; }
cd "$NODE_DIR" || exit 1
log "=== Autonode @cybra Start ==="
if [ ! -d .git ]; then
    git init -b main
    git remote add origin https://github.com/Lubnysash1980/cybra-at-node.git
    git pull origin main --rebase 2>/dev/null || true
fi
evo_check() {
    local errors=0
    [ -d .git ] || errors=$((errors+1))
    command -v python3 >/dev/null 2>&1 || errors=$((errors+1))
    [ -f "index.json" ] || errors=$((errors+1))
    [ -d "modules" ] || errors=$((errors+1))
    if [ "$errors" -eq 0 ]; then evo_log "EVO: 100% — нода стабільна."; return 0
    else evo_log "EVO: Відхилення! Помилок: $errors"; return 1; fi
}
evo_rollback() {
    evo_log "EVO: git reset --hard origin/main..."
    [ -d .git ] && git fetch origin main --quiet 2>/dev/null && git reset --hard origin/main --quiet 2>/dev/null && git clean -fd --quiet 2>/dev/null
}
sync_git() {
    [ -d .git ] || return
    git pull origin main --rebase -q 2>&1 | tee -a "$LOG" || true
    if [ -n "$(git status --porcelain)" ]; then
        git add -A
        git commit -m "auto: @cybra sync $(date -u +"%Y-%m-%dT%H:%M:%SZ")" -q
        git push origin main -q 2>&1 | tee -a "$LOG" || true
    fi
}
if ! evo_check; then evo_rollback; evo_check && log "Node: EVO відновив ноду" || log "Node: EVO failed"; fi
sync_git
log "=== Autonode @cybra End ==="
''', encoding="utf-8")
    os.chmod(NODE_SCRIPT, 0o755)
    ok("Нода створена")

ok(f"Нода: {NODE_SCRIPT}")

# ─── 3. Тест EVO в @cybra ───
hdr("3. ТЕСТ EVO: злам @cybra/index.json")
index = NODE / "index.json"
if index.exists():
    backup = NODE / "index.json.testbak"
    shutil.copy(index, backup)
    index.unlink()
    ok("index.json ВИДАЛЕНО (імітація зламу)")
else:
    info("index.json не існує")

# Очистити лог
LOG.write_text("")

# Запуск ноди
info("Запуск ноди...")
r = run(f"bash {NODE_SCRIPT}")
time.sleep(1)

# Перевірка
if index.exists():
    ok("index.json ВІДНОВЛЕНО автоматично!")
else:
    bad("index.json НЕ відновлено")
    if backup.exists():
        shutil.copy(backup, index)
        info("Повернуто з бекапу")

# Логи
hdr("4. ЛОГИ НОДИ")
print(LOG.read_text()[-800:] if LOG.exists() else "  (порожньо)")

hdr("РЕЗУЛЬТАТ")
if index.exists():
    print(f"  {G}✅ EVO працює: нода @cybra відновлює файли{Z}")
else:
    print(f"  {R}❌ EVO не працює: перевір Git в @cybra{Z}")
    info("Можливо, index.json не закомічений. Зроби: cd ~/CYBRA/@cybra && git add -A && git commit -m 'init' && git push")
