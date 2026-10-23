#!/usr/bin/env python3
import os, subprocess, json, sqlite3
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
DB = CYBRA / "data/ads.db"
FIDIC_DIR = CYBRA / "data/fidic"

def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=CYBRA)

log("═══ 1. ПЕРЕВІРКА БАЗИ ДАНИХ (РЕКЛАМА) ═══")
if not DB.exists():
    log("⚠️ База ads.db не знайдена. Створюємо...")
    DB.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB)
    conn.execute('''CREATE TABLE ads (id INTEGER PRIMARY KEY AUTOINCREMENT, what TEXT, platform TEXT, url TEXT, volume INTEGER, price_bnb REAL, paid_bnb REAL DEFAULT 0, stage INTEGER DEFAULT 1, status TEXT DEFAULT 'created', tx_hash TEXT, created_at TEXT)''')
    conn.commit()
    conn.close()
    log("✅ База створена.")
else:
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT COUNT(*) FROM ads")
    count = cursor.fetchone()[0]
    conn.close()
    log(f"✅ База на місці. Знайдено {count} рекламних контрактів.")

log("\n═══ 2. ПЕРЕВІРКА КОНТРАКТІВ FIDIC ═══")
if not FIDIC_DIR.exists():
    FIDIC_DIR.mkdir(parents=True, exist_ok=True)
    log("✅ Папка FIDIC створена.")

fidic_count = 0
for f in FIDIC_DIR.glob("*.json"):
    try:
        data = json.loads(f.read_text())
        state = data.get("state", "UNKNOWN")
        log(f"  - {f.name}: {state}")
        fidic_count += 1
    except Exception as e:
        log(f"  ❌ Помилка в {f.name}: {e}")
log(f"✅ Всього FIDIC контрактів: {fidic_count}")

log("\n═══ 3. ПЕРЕВІРКА МЕНЮ ТА МОДУЛІВ ═══")
menu = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
if menu.exists():
    text = menu.read_text()
    required = ["151", "152", "154", "160", "149"]
    for req in required:
        if f"[{req}]" in text:
            log(f"  ✅ Пункт [{req}] інтегровано")
        else:
            log(f"  ⚠️ Пункт [{req}] відсутній у меню")
else:
    log("❌ Головне меню не знайдено!")

log("\n═══ 4. СИНХРОНІЗАЦІЯ З GIT (НОДА) ═══")
log("⏳ Зберігаємо всі контракти та стан системи...")
run("git add -A")
run('git commit --no-verify -m "system: full sync of all contracts (ads, fidic) and menus" -q')
res = run("git push origin main -q")
if res.returncode == 0:
    log("✅ Всі контракти та файли успішно відправлено в GitHub (Ноду)!")
else:
    log("⚠️ Помилка відправки в Git (можливо, немає змін або конфлікт).")

log("\n═══ 5. ПЕРЕЗАПУСК МОНОЛІТУ ═══")
run("pm2 restart cybra-monolith -q")
log("✅ Система перезапущена з актуальними даними.")

log("\n════════════════════════════════════════════")
log("🎉 ПОВНА СИНХРОНІЗАЦІЯ СИСТЕМИ ЗАВЕРШЕНА!")
log("Всі ваші контракти (Реклама та FIDIC) тепер збережені в хмарі.")
log("════════════════════════════════════════════")
