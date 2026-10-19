#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
DB="$CYBRA/data/ads.db"
LEVEL_FILE="$CYBRA/state/module_151.level"
BACKUP="$CYBRA/backup/ads.db.bak"
mkdir -p "$CYBRA/data" "$CYBRA/logs" "$CYBRA/state" "$CYBRA/backup"

sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS ads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  what TEXT, platform TEXT, url TEXT,
  volume INTEGER, price_bnb REAL, paid_bnb REAL DEFAULT 0,
  stage INTEGER DEFAULT 1, status TEXT DEFAULT 'created',
  tx_hash TEXT, created_at TEXT);" 2>/dev/null

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

backup_db() { cp "$DB" "$BACKUP" 2>/dev/null && echo "✅ Бекап: $BACKUP"; }
restore_db() { [ -f "$BACKUP" ] || { echo "❌ Немає бекапу"; return 1; }; cp "$BACKUP" "$DB" && echo "✅ Відновлено"; }

ai_estimate() {
    local what="$1" platform="$2" url="$3" volume=3
    case "$(echo "$platform" | tr 'A-Z' 'a-z')" in
        *tiktok*) volume=5 ;; *facebook*|*fb*) volume=6 ;;
        *instagram*|*inst*) volume=6 ;; *youtube*) volume=7 ;;
        *сайт*|*site*) volume=4 ;;
    esac
    [ ${#what} -gt 20 ] && volume=$((volume+1))
    [ ${#what} -gt 50 ] && volume=$((volume+1))
    echo "$url" | grep -qE '\.(com|io|org)' && volume=$((volume+1))
    [ "$volume" -gt 7 ] && volume=7; [ "$volume" -lt 1 ] && volume=1
    local price=$(echo "scale=4; $volume * 0.01" | bc 2>/dev/null || echo "0.01")
    echo "$volume $price"
}

ad_create() {
    local what platform url volume price
    if [ $# -ge 3 ]; then what="$1"; platform="$2"; url="$3"
    else
        read -r -p "Що рекламуємо: " what; [ -z "$what" ] && return 1
        read -r -p "Платформа: " platform; [ -z "$platform" ] && return 1
        read -r -p "URL: " url
    fi
    echo "$url" | grep -qE '^https?://' || { echo "❌ URL"; return 1; }
    read volume price <<< "$(ai_estimate "$what" "$platform" "$url")"
    backup_db
    local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local id=$(sqlite3 "$DB" "INSERT INTO ads (what,platform,url,volume,price_bnb,created_at) VALUES ('$what','$platform','$url',$volume,$price,'$now'); SELECT last_insert_rowid();")
    echo "🤖 AI: $volume/7, $price BNB"
    echo "✅ Реклама #$id"
}

ad_status() {
    echo ""
    printf "%-3s %-19s %-10s %-6s %-6s %s\n" "ID" "Що" "Платформа" "Ціна" "Оплач" "Прогрес"
    sqlite3 -separator '|' "$DB" "SELECT id, substr(what,1,18), platform, price_bnb, paid_bnb, stage FROM ads ORDER BY id DESC LIMIT 10;" 2>/dev/null | while IFS='|' read -r id what plat price paid stage; do
        local bar=""
        for i in 1 2 3 4 5 6 7; do
            [ "$i" -le "$stage" ] && bar="${bar}🟢" || bar="${bar}⚪"
        done
        printf "%-3s %-19s %-10s %-6s %-6s %s\n" "$id" "$what" "$plat" "$price" "$paid" "$bar"
    done
}

ad_pay() {
    read -r -p "ID: " id; read -r -p "TX hash: " tx
    [ -z "$id" ] || [ -z "$tx" ] && return 1
    backup_db
    sqlite3 "$DB" "UPDATE ads SET stage=4, tx_hash='$tx', paid_bnb=price_bnb, status='paid' WHERE id=$id;" 2>/dev/null
    echo "✅ #$id оплачено (stage=4)"
}

ad_refund() {
    read -r -p "ID: " id; backup_db
    sqlite3 "$DB" "UPDATE ads SET status='refunded', stage=7 WHERE id=$id;" 2>/dev/null
    echo "✅ #$id → refunded"
}

run_levels
case "${1:-menu}" in
    create) shift; ad_create "$@" ;;
    status) ad_status ;;
    backup) backup_db ;;
    restore) restore_db ;;
    menu|*)
        while true; do
            echo ""
            echo "════ 151. РЕКЛАМА (рівень $(level_now)/7) ════"
            echo "1) Створити  2) Статус  3) Оплатити  4) Реверс  5) Бекап  6) Відкат  0) Назад"
            read -r -p "Вибір: " c
            case "$c" in
                1) ad_create ;; 2) ad_status ;; 3) ad_pay ;; 4) ad_refund ;;
                5) backup_db ;; 6) restore_db ;; 0) exit 0 ;; *) echo "невідомо" ;;
            esac
        done ;;
esac
