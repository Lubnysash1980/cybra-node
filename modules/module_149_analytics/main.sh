#!/data/data/com.termux/files/usr/bin/bash
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
