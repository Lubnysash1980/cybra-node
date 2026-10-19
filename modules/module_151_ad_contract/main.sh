#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 151: Реклама (Ad Contract) + SQLite + 7 рівнів
CYBRA="$HOME/CYBRA"
DB="$CYBRA/data/ads.db"
LEVEL_FILE="$CYBRA/state/module_151.level"
mkdir -p "$CYBRA/data" "$CYBRA/logs" "$CYBRA/state"

sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS ads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  what TEXT, platform TEXT, url TEXT,
  volume INTEGER, price_bnb REAL,
  status TEXT DEFAULT 'created', created_at TEXT);" 2>/dev/null

level_now() { [ -f "$LEVEL_FILE" ] && cat "$LEVEL_FILE" || echo 1; }
level_set() { echo "$1" > "$LEVEL_FILE"; }
level1() { [ -d "$CYBRA" ] && return 0 || return 1; }
level2() { command -v sqlite3 >/dev/null && return 0 || return 1; }
level3() { sqlite3 "$DB" "SELECT 1;" >/dev/null 2>&1 && return 0 || return 1; }
level4() { [ -f "$DB" ] && return 0 || return 1; }
level5() { [ -f "$CYBRA/evo/evo_core.py" ] && return 0 || return 1; }
level6() { [ -d "$CYBRA/modules" ] && return 0 || return 1; }
level7() { [ -d "$CYBRA/sandbox" ] && return 0 || return 1; }
run_levels() {
    local cur=$(level_now)
    for i in 1 2 3 4 5 6 7; do
        [ "$i" -lt "$cur" ] && continue
        if "level$i"; then level_set "$i"; else return 0; fi
    done
}

ad_create() {
    local what platform url volume
    if [ $# -ge 4 ]; then
        what="$1"; platform="$2"; url="$3"; volume="$4"
    else
        echo ""
        read -r -p "Що рекламуємо: " what
        read -r -p "Платформа: " platform
        read -r -p "URL: " url
        read -r -p "Обсяг (1-7): " volume
    fi
    [ -z "$what" ] && { echo "❌ порожньо"; return 1; }
    [ -z "$platform" ] && { echo "❌ порожньо"; return 1; }
    echo "$url" | grep -qE '^https?://' || { echo "❌ URL невалідний"; return 1; }
    echo "$volume" | grep -qE '^[1-7]$' || { echo "❌ Обсяг 1-7"; return 1; }
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

run_levels

if [ "$1" = "create" ] && [ $# -ge 5 ]; then
    ad_create "$2" "$3" "$4" "$5"
    exit 0
fi

clear 2>/dev/null
while true; do
    echo ""
    echo "════════ 151. РЕКЛАМА (рівень $(level_now)/7) ════════"
    echo "1) Створити  2) Статус  3) Реверс  0) Назад"
    read -r -p "Вибір: " c
    case "$c" in
        1) ad_create ;;
        2) ad_status ;;
        3) ad_refund ;;
        0) exit 0 ;;
        *) echo "невідомо" ;;
    esac
done
