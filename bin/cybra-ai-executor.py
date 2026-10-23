#!/usr/bin/env python3
import os, subprocess
from pathlib import Path
from datetime import datetime

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MOD_DIR = CYBRA / "modules" / "module_149_analytics"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

print("🤖 ШІ-Екзекутор: Запуск створення модуля 149...")

# 1. Створюємо папку та файл модуля
MOD_DIR.mkdir(parents=True, exist_ok=True)
MAIN_SH = MOD_DIR / "main.sh"

ai_code = """#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 149: Аналітика системи (Створено ШІ)
CYBRA="$HOME/CYBRA"
DB="$CYBRA/data/ads.db"
FIDIC_DIR="$CYBRA/data/fidic"

clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [149] АНАЛІТИКА СИСТЕМИ (AI MODULE)"
echo "════════════════════════════════════════════"

echo "─── 1. Процеси (PM2) ───"
if command -v pm2 >/dev/null 2>&1; then
    pm2 ls | grep -E "cybra|name" | head -5
else
    echo "⚠️ PM2 не встановлено"
fi
echo ""

echo "─── 2. Реклама (База даних) ───"
if [ -f "$DB" ]; then
    TOTAL_ADS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads;" 2>/dev/null || echo "0")
    PAID_ADS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE status='paid' OR status='completed';" 2>/dev/null || echo "0")
    echo "Всього реклам: $TOTAL_ADS"
    echo "Оплачено/Завершено: $PAID_ADS"
else
    echo "База даних реклами не знайдена."
fi
echo ""

echo "─── 3. FIDIC Контракти ───"
if [ -d "$FIDIC_DIR" ]; then
    TOTAL_FIDIC=$(ls "$FIDIC_DIR"/*.json 2>/dev/null | wc -l)
    echo "Всього FIDIC контрактів: $TOTAL_FIDIC"
    for f in "$FIDIC_DIR"/*.json; do
        if [ -f "$f" ]; then
            CID=$(basename "$f" .json)
            STATE=$(python3 -c "import json; print(json.load(open('$f')).get('state','?'))" 2>/dev/null)
            echo "  - $CID: $STATE"
        fi
    done
else
    echo "Папка FIDIC порожня."
fi
echo ""

echo "─── 4. Синхронізація ───"
cd "$CYBRA" || exit
LAST_COMMIT=$(git log -1 --format="%h %s" 2>/dev/null)
if [ -n "$LAST_COMMIT" ]; then
    echo "Останній коміт: $LAST_COMMIT"
else
    echo "Git історія порожня."
fi
echo ""

echo "════════════════════════════════════════════"
read -r -p "Натисни Enter для виходу..." _
"""

MAIN_SH.write_text(ai_code)
os.chmod(MAIN_SH, 0o755)
print("✅ ШІ створив файл: modules/module_149_analytics/main.sh")

# 2. Інтеграція в меню
if MENU.exists():
    lines = MENU.read_text().splitlines()
    new_lines = []
    for line in lines:
        # Замінюємо заглушку 149 на наш новий модуль
        if "149)" in line and "module_149_base" in line:
            new_lines.append('        149) bash "$HOME/CYBRA/modules/module_149_analytics/main.sh" ;;')
        elif "100|101|102" in line:
            # Якщо 149 захований у загальному списку, витягуємо його окремо
            new_lines.append('        149) bash "$HOME/CYBRA/modules/module_149_analytics/main.sh" ;;')
            new_lines.append(line)
        else:
            new_lines.append(line)
            
    MENU.write_text("\n".join(new_lines) + "\n")
    print("✅ ШІ оновив меню: пункт [149] тепер веде на Аналітику")

# 3. Зберігаємо в Git
print("⏳ Зберігаю в Git...")
subprocess.run("git add -A && git commit -m 'AI: generated module 149 analytics' -q && git push origin main -q", shell=True, cwd=CYBRA)

print("")
print("🎉 ГОТОВО! ШІ успішно створив та інтегрував модуль 149.")
print("Запустіть 'cybra' і натисніть 149, щоб побачити результат!")
