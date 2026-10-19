#!/data/data/com.termux/files/usr/bin/bash
# Контролер 100% РЕЗУЛЬТАТУ для реклами
# Веде за станом: створено → оцінено → оплачено → підписано → результат
CYBRA="$HOME/CYBRA"
DB="$CYBRA/data/ads.db"
STATE_FILE="$CYBRA/state/ad_result.pct"
LOG="$CYBRA/logs/ad_result-controller.log"
mkdir -p "$CYBRA/logs" "$CYBRA/state"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }
state() { cat "$STATE_FILE" 2>/dev/null || echo 0; }
set_state() { echo "$1" > "$STATE_FILE"; log "STATE: $1%"; echo "  Стан: $1%"; }

# ─── КРОКИ ДО 100% ───
step1_created() {
    local n=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads;" 2>/dev/null || echo 0)
    [ "$n" -gt 0 ] && { echo "  [1] ✅ Створено: $n реклам"; return 0; }
    echo "  [1] ❌ Немає реклам"; return 1
}

step2_estimated() {
    local n=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE price_bnb > 0;" 2>/dev/null || echo 0)
    [ "$n" -gt 0 ] && { echo "  [2] ✅ Оцінено: $n"; return 0; }
    echo "  [2] ❌ Не оцінено"; return 1
}

step3_paid() {
    local n=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE status='paid';" 2>/dev/null || echo 0)
    [ "$n" -gt 0 ] && { echo "  [3] ✅ Оплачено: $n"; return 0; }
    echo "  [3] ⏳ Очікує оплати"; return 1
}

step4_signed() {
    local n=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE status='signed';" 2>/dev/null || echo 0)
    [ "$n" -gt 0 ] && { echo "  [4] ✅ Підписано: $n"; return 0; }
    echo "  [4] ⏳ Очікує підпису"; return 1
}

step5_result() {
    local n=$(sqlite3 "$DB" "SELECT COUNT(*) FROM ads WHERE status='completed';" 2>/dev/null || echo 0)
    [ "$n" -gt 0 ] && { echo "  [5] ✅ Результат: $n"; return 0; }
    echo "  [5] ⏳ Очікує результату"; return 1
}

# ─── ПРОХОДЖЕННЯ ШЛЯХУ ───
run_path() {
    echo "═══ Шлях до 100% результату ═══"
    local pct=0
    step1_created && pct=20
    step2_estimated && pct=40
    step3_paid && pct=60
    step4_signed && pct=80
    step5_result && pct=100
    set_state "$pct"
    if [ "$pct" -eq 100 ]; then
        echo "🎯 100% РЕЗУЛЬТАТ ДОСЯГНУТО"
        log "RESULT: 100%"
    else
        echo "⏸  Стан: $pct% — наступний крок: $((pct/20 + 1))"
    fi
}

# ─── ДІЇ ───
pay() {
    read -r -p "ID: " id; read -r -p "TX: " tx
    sqlite3 "$DB" "UPDATE ads SET status='paid', stage=4, tx_hash='$tx' WHERE id=$id;" 2>/dev/null
    echo "✅ #$id оплачено"
    run_path
}
sign() {
    read -r -p "ID: " id
    sqlite3 "$DB" "UPDATE ads SET status='signed', stage=5 WHERE id=$id;" 2>/dev/null
    echo "✅ #$id підписано"
    run_path
}
complete() {
    read -r -p "ID: " id
    sqlite3 "$DB" "UPDATE ads SET status='completed', stage=7 WHERE id=$id;" 2>/dev/null
    echo "✅ #$id завершено (результат)"
    run_path
}

case "${1:-path}" in
    path|status) run_path ;;
    pay) pay ;;
    sign) sign ;;
    complete) complete ;;
    state) echo "Стан: $(state)%" ;;
    *) run_path ;;
esac
