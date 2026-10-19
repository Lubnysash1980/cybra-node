#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 151: Реклама (Ad Contract) — робоча версія з AI-оцінкою
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

# ─── AI-оцінка обсягу та ціни ───
ai_estimate() {
    local what="$1" platform="$2" url="$3"
    local volume=3  # базовий
    # платформа
    case "$(echo "$platform" | tr 'A-Z' 'a-z')" in
        *tiktok*) volume=5 ;;
        *facebook*|*fb*) volume=6 ;;
        *instagram*|*inst*) volume=6 ;;
        *youtube*) volume=7 ;;
        *сайт*|*site*) volume=4 ;;
        *) volume=3 ;;
    esac
    # довжина назви
    local len=${#what}
    [ "$len" -gt 20 ] && volume=$((volume+1))
    [ "$len" -gt 50 ] && volume=$((volume+1))
    # домен
    echo "$url" | grep -qE '\.(com|io|org)' && volume=$((volume+1))
    [ "$volume" -gt 7 ] && volume=7
    [ "$volume" -lt 1 ] && volume=1
    local price=$(echo "scale=4; $volume * 0.01" | bc 2>/dev/null || echo "0.01")
    echo "$volume $price"
}

ad_create() {
    local what platform url volume price
    if [ $# -ge 3 ]; then
        what="$1"; platform="$2"; url="$3"
    else
        echo ""
        read -r -p "Що рекламуємо: " what
        [ -z "$what" ] && { echo "❌ порожньо"; return 1; }
        read -r -p "Платформа (TikTok/FB/Instagram/YouTube/сайт): " platform
        [ -z "$platform" ] && { echo "❌ порожньо"; return 1; }
        read -r -p "URL: " url
    fi
    echo "$url" | grep -qE '^https?://' || { echo "❌ URL невалідний: '$url'"; return 1; }

    # AI сам визначає обсяг і ціну
    read volume price <<< "$(ai_estimate "$what" "$platform" "$url")"

    local now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local id=$(sqlite3 "$DB" "INSERT INTO ads (what,platform,url,volume,price_bnb,created_at) VALUES ('$what','$platform','$url',$volume,$price,'$now'); SELECT last_insert_rowid();")
    echo ""
    echo "🤖 AI-оцінка:"
    echo "   Обсяг: $volume/7 (визначено автоматично)"
    echo "   Ціна:  $price BNB"
    echo "   Розподіл: 50% вам, 50% менеджеру"
    echo ""
    echo "✅ Реклама #$id створена"
}
ad_status() {
    echo ""
    echo "════════ СТАТУС РЕКЛАМ ════════"
    sqlite3 -header -column "$DB" "SELECT id,what,platform,volume,price_bnb,status,created_at FROM ads ORDER BY id DESC LIMIT 10;" 2>/dev/null
    if [ -z "$(sqlite3 "$DB" "SELECT id FROM ads LIMIT 1;" 2>/dev/null)" ]; then
        echo "  (порожньо)"
    fi
}
ad_refund() {
    echo ""
    ad_status
    echo ""
    read -r -p "ID для реверсу: " id
    [ -z "$id" ] && { echo "❌ порожньо"; return; }
    local n=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE id=$id;" 2>/dev/null)
    [ "$n" = "0" ] && { echo "❌ #$id не знайдено"; return; }
    sqlite3 "$DB" "UPDATE ads SET status='refunded' WHERE id=$id;" 2>/dev/null
    echo "✅ #$id → refunded"
}

run_levels

if [ "$1" = "create" ] && [ $# -ge 4 ]; then
    ad_create "$2" "$3" "$4"
    exit 0
fi

while true; do
    echo ""
    echo "════════ 151. РЕКЛАМА (рівень $(level_now)/7) ════════"
    echo "1) Створити (AI сам визначить обсяг і ціну)"
    echo "2) Статус"
    echo "3) Реверс"
    echo "0) Назад"
    read -r -p "Вибір: " c
    case "$c" in
        1) ad_create ;;
        2) ad_status ;;
        3) ad_refund ;;
        0) exit 0 ;;
        *) echo "невідомо" ;;
    esac
done
