#!/data/data/com.termux/files/usr/bin/bash
# ═══════════════════════════════════════════════════════════════
# МОДУЛЬ 151: РЕКЛАМА (Ad Contract) — ПОВНИЙ 100% СКРИПТ
# 7 рівнів + AI + оплата + підпис + результат + бекап + відкат
# ═══════════════════════════════════════════════════════════════
CYBRA="$HOME/CYBRA"
DB="$CYBRA/data/ads.db"
LEVEL_FILE="$CYBRA/state/module_151.level"
BACKUP="$CYBRA/backup/ads.db.bak"
NODE_CTRL="$CYBRA/controllers/node-controller.sh"
LOG="$CYBRA/logs/module_151_ad_contract.log"
mkdir -p "$CYBRA/data" "$CYBRA/logs" "$CYBRA/state" "$CYBRA/backup"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

# ─── БАЗА + МІГРАЦІЯ ───
sqlite3 "$DB" "CREATE TABLE IF NOT EXISTS ads (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  what TEXT, platform TEXT, url TEXT,
  volume INTEGER, price_bnb REAL,
  status TEXT DEFAULT 'created', created_at TEXT);" 2>/dev/null
for col in "paid_bnb REAL DEFAULT 0" "stage INTEGER DEFAULT 1" "tx_hash TEXT" "payment_status TEXT DEFAULT 'unpaid'"; do
    sqlite3 "$DB" "ALTER TABLE ads ADD COLUMN $col;" 2>/dev/null
done

# ─── 7 РІВНІВ ───
level_now() { [ -f "$LEVEL_FILE" ] && cat "$LEVEL_FILE" || echo 1; }
level_set() { echo "$1" > "$LEVEL_FILE"; log "LEVEL: $1"; }
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

# ─── НОДА (100% СТАН) ───
check_node() {
    [ -f "$NODE_CTRL" ] && "$NODE_CTRL" path >/dev/null 2>&1
}

# ─── БЕКАП / ВІДКАТ ───
backup_db() { cp "$DB" "$BACKUP" 2>/dev/null && echo "✅ Бекап: $BACKUP"; }
restore_db() { [ -f "$BACKUP" ] || { echo "❌ Немає бекапу"; return 1; }; cp "$BACKUP" "$DB" && echo "✅ Відновлено"; }

# ─── AI-ОЦІНКА ───
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

# ─── СТВОРЕННЯ ───
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

# ─── СТАТУС ───
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

# ─── ОПЛАТА ───
ad_pay() {
    local id tx
    if [ $# -ge 2 ]; then id="$1"; tx="$2"; else read -r -p "ID: " id; read -r -p "TX hash: " tx; fi
    [ -z "$id" ] || [ -z "$tx" ] && return 1
    backup_db
    sqlite3 "$DB" "UPDATE ads SET stage=4, tx_hash='$tx', paid_bnb=price_bnb, status='paid' WHERE id=$id;" 2>/dev/null
    echo "✅ #$id оплачено (stage=4)"
}

# ─── ПІДПИС ───
ad_sign() {
    local id
    if [ $# -ge 1 ]; then id="$1"; else read -r -p "ID: " id; fi
    [ -z "$id" ] && { echo "❌ ID порожній"; return 1; }
    local n=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE id=$id;" 2>/dev/null)
    [ "$n" = "0" ] && { echo "❌ #$id не знайдено"; return 1; }
    sqlite3 "$DB" "UPDATE ads SET stage=5, status='signed' WHERE id=$id;" 2>/dev/null
    echo "✅ #$id підписано (stage=5)"
}

# ─── РЕЗУЛЬТАТ ───
ad_complete() {
    local id
    if [ $# -ge 1 ]; then id="$1"; else read -r -p "ID: " id; fi
    [ -z "$id" ] && { echo "❌ ID порожній"; return 1; }
    local n=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE id=$id;" 2>/dev/null)
    [ "$n" = "0" ] && { echo "❌ #$id не знайдено"; return 1; }
    sqlite3 "$DB" "UPDATE ads SET stage=7, status='completed' WHERE id=$id;" 2>/dev/null
    echo "✅ #$id завершено (результат)"
}

# ─── РЕВЕРС ───
ad_refund() {
    read -r -p "ID: " id; backup_db
    sqlite3 "$DB" "UPDATE ads SET status='refunded', stage=7 WHERE id=$id;" 2>/dev/null
    echo "✅ #$id → refunded"
}

# ─── ПРОГРЕС 100% ───
ad_progress() {
    echo "═══ ШЛЯХ ДО 100% РЕКЛАМИ ═══"
    local pct=0
    [ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads;" 2>/dev/null || echo 0)" -gt 0 ] && { echo "  [1] ✅ Створено"; pct=20; }
    [ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE price_bnb>0;" 2>/dev/null || echo 0)" -gt 0 ] && { echo "  [2] ✅ Оцінено"; pct=40; }
    [ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE status='paid';" 2>/dev/null || echo 0)" -gt 0 ] && { echo "  [3] ✅ Оплачено"; pct=60; }
    [ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE status='signed';" 2>/dev/null || echo 0)" -gt 0 ] && { echo "  [4] ✅ Підписано"; pct=80; }
    [ "$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE status='completed';" 2>/dev/null || echo 0)" -gt 0 ] && { echo "  [5] ✅ Результат"; pct=100; }
    echo "Стан: $pct%"
}

# ─── ЗАПУСК ───
run_levels
check_node

case "${1:-menu}" in
    create) shift; ad_create "$@" ;;
    status) ad_status ;;
    backup) backup_db ;;
    restore) restore_db ;;
    pay) shift; ad_pay "$@" ;;
    sign) shift; ad_sign "$@" ;;
    complete) shift; ad_complete "$@" ;;
    refund) ad_refund ;;
    progress) ad_progress ;;
    menu|*)
        while true; do
            echo ""
            echo "════ 151. РЕКЛАМА (рівень $(level_now)/7) ════"
            echo "1) Створити  2) Статус  3) Оплатити  4) Підписати  5) Результат  6) Реверс  7) Бекап  8) Відкат  9) Прогрес  0) Назад"
            read -r -p "Вибір: " c
            case "$c" in
                1) ad_create ;; 2) ad_status ;; 3) ad_pay ;; 4) ad_sign ;;
                5) ad_complete ;; 6) ad_refund ;; 7) backup_db ;; 8) restore_db ;;
                9) ad_progress ;; 0) exit 0 ;; *) echo "невідомо" ;;
            esac
        done ;;
esac
