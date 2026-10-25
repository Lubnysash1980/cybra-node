#!/data/data/com.termux/files/usr/bin/bash
# ── BINMIX/EXECUTOR METADATA (auto-added) ──
# module: module_149
# source: github_history  rev=832d90ae  when=2026-10-23T17:12:15+03:00
# score: 218  size: 1856B  hash: 276f532807ae
# mixed_at: 2026-10-24T20:29:29.482290+00:00
# ──────────────────────────────────────────
# МОДУЛЬ 149: Аналітика системи (CYBRA Analytics)

CYBRA="$HOME/CYBRA"
DB="$CYBRA/data/ads.db"
FIDIC_DIR="$CYBRA/data/fidic"

clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [149] АНАЛІТИКА СИСТЕМИ"
echo "════════════════════════════════════════════"

# 1. Аналітика PM2 (Моноліт)
echo "─── 1. Процеси (PM2) ───"
if command -v pm2 >/dev/null 2>&1; then
    pm2 ls | grep -E "cybra|name" | head -5
else
    echo "⚠️ PM2 не встановлено"
fi
echo ""

# 2. Аналітика реклами (SQLite)
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

# 3. Аналітика FIDIC
echo "─── 3. FIDIC Контракти ───"
if [ -d "$FIDIC_DIR" ]; then
    TOTAL_FIDIC=$(ls "$FIDIC_DIR"/*.json 2>/dev/null | wc -l)
    echo "Всього FIDIC контрактів: $TOTAL_FIDIC"
    
    # Виводимо статуси контрактів
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

# 4. Синхронізація
echo "─── 4. Синхронізація з Нодою ───"
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
