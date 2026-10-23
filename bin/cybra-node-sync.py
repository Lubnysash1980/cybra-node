#!/usr/bin/env python3
import os, time, subprocess
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LOG = CYBRA / "logs/node_sync.log"
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {msg}\n")

def run(cmd, cwd=None):
    try: return subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd, timeout=60)
    except: return None

def sync_node():
    log("🔄 Синхронізація з Нодою (GitHub)...")
    
    # 1. Отримуємо зміни з сервера (безпечно, без reset)
    run("git fetch origin main -q", cwd=CYBRA)
    
    # Перевіряємо, чи є нові коміти на сервері
    status = run("git status -uno", cwd=CYBRA)
    if status and "Your branch is behind" in status.stdout:
        log("📥 Знайдено оновлення на сервері. Робимо git pull --rebase...")
        res = run("git pull origin main --rebase -q", cwd=CYBRA)
        if res and res.returncode == 0:
            log("✅ Оновлення успішно застосовано.")
        else:
            log("⚠️ Помилка при pull (можливий конфлікт). Скасовуємо rebase.")
            run("git rebase --abort", cwd=CYBRA)

    # 2. Відправляємо локальні зміни (пульс, контракти) на сервер
    local_status = run("git status --porcelain", cwd=CYBRA)
    if local_status and local_status.stdout.strip():
        log("📤 Є локальні зміни. Відправляємо в Ноду...")
        run("git add -A", cwd=CYBRA)
        run('git commit -m "auto-sync: node heartbeat and state updates" -q', cwd=CYBRA)
        
        # Пробуємо запушити
        push = run("git push origin main -q", cwd=CYBRA)
        if push and push.returncode == 0:
            log("✅ Локальні зміни успішно відправлено.")
        else:
            log("⚠️ Push не вдався. Ймовірно, хтось інший встиг запушити. Робимо pull + push.")
            run("git pull origin main --rebase -q", cwd=CYBRA)
            run("git push origin main -q", cwd=CYBRA)

def main():
    log("=== NODE SYNC CONTROLLER STARTED ===")
    while True:
        try:
            sync_node()
        except Exception as e:
            log(f"❌ ПОМИЛКА SYNC: {e}")
        
        # Синхронізація кожні 15 хвилин (щоб не завантажувати мережу і не спамити Git)
        time.sleep(900)

if __name__ == "__main__":
    main()
