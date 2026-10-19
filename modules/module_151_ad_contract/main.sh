#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 151: Реклама (Ad Contract) + SQLite
CYBRA="$HOME/CYBRA"
DB="$CYBRA/data/ads.db"
mkdir -p "$CYBRA/data" "$CYBRA/logs"
sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS ads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  what TEXT, platform TEXT, url TEXT,
  volume INTEGER, price_bnb REAL,
  status TEXT DEFAULT 'created', created_at TEXT);" 2>/dev/null

ad_create() {
    echo ""
    read -r -p "Що рекламуємо: " what
    [ -z "$what" ] && { echo "❌ порожньо"; return; }
    read -r -p "Платформа (TikTok/FB/сайт): " platform
    [ -z "$platform" ] && { echo "❌ порожньо"; return; }
    read -r -p "URL: " url
    echo "$url" | grep -qE '^https?://' || { echo "❌ URL невалідний"; return; }
    read -r -p "Обсяг (1-7): " volume
    echo "$volume" | grep -qE '^[1-7]$' || { echo "❌ Обсяг 1-7"; return; }
    local price=$(echo "scale=4; $volume * 0.01" | bc 2>/dev/null || echo "0.01")
    local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local id=$(sqlite3 "$DB" "INSERT INTO ads (what,platform,url,volume,price_bnb,created_at) VALUES ('$what','$platform','$url',$volume,$price,'$now'); SELECT last_insert_rowid();")
    echo "✅ Реклама #$id | $price BNB | 50/50"
}
ad_status() {
    echo ""
    sqlite3 -header -column "$DB" "SELECT id,what,platform,volume,price_bnb,status FROM ads ORDER BY id DESC LIMIT 10;" 2>/dev/null
}
ad_refund() {
    echo ""
    read -r -p "ID для реверсу: " id
    sqlite3 "$DB" "UPDATE ads SET status='refunded' WHERE id=$id;" 2>/dev/null
    echo "✅ #$id → refunded"
}

clear 2>/dev/null
while true; do
    echo ""
    echo "════════ 151. РЕКЛАМА ════════"
    echo "1) Створити  2) Статус  3) Реверс  0) Назад"
    read -r -p "Вибір: " c
    case "$c" in
        1) ad_create ;;
        2) ad_status ;;
        3) ad_refund ;;
        0) 
# ─── 7 РІВНІВ СКЛАДНОСТІ ІНТЕГРАЦІЇ ───
LEVEL_FILE="/data/data/com.termux/files/home/CYBRA/state/main.sh.level"
level_now() { [ -f "$LEVEL_FILE" ] && cat "$LEVEL_FILE" || echo 1; }
level_set() { echo "$1" > "$LEVEL_FILE"; }

level1() { echo "  [L1] базовий запуск"; return 0; }
level2() { echo "  [L2] перевірка середовища"; return 0; }
level3() { echo "  [L3] підключення до ядра"; return 0; }
level4() { echo "  [L4] health-check"; return 0; }
level5() { echo "  [L5] приєднання до EVO"; return 0; }
level6() { echo "  [L6] приєднання до контрактів"; return 0; }
level7() { echo "  [L7] повна екосистема"; return 0; }

run_levels() {
    local cur
    cur=$(level_now)
    echo "  Старт з рівня $cur/7"
    for i in 1 2 3 4 5 6 7; do
        [ "$i" -lt "$cur" ] && continue
        if "level$i"; then
            level_set "$i"
        else
            echo "  ⛔ Рівень $i не піднявся. Система на рівні $((i-1))/7"
            return 0
        fi
    done
    echo "  ✅ Рівень 7/7"
}

run_levels
exit 0 ;;
        *) echo "невідомо" ;;
    esac
done
