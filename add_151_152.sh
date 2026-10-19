#!/data/data/com.termux/files/usr/bin/bash
set -e
CYBRA="$HOME/CYBRA"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

echo "═══ ДОДАВАННЯ ПУНКТІВ 151 І 152 ═══"

# 1. Створюємо модулі 151 і 152
mkdir -p "$CYBRA/modules/module_151_ad_contract"
mkdir -p "$CYBRA/modules/module_152_rollback_evo"

cat > "$CYBRA/modules/module_151_ad_contract/main.sh" <<'ADEOF'
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
        0) exit 0 ;;
        *) echo "невідомо" ;;
    esac
done
ADEOF
chmod +x "$CYBRA/modules/module_151_ad_contract/main.sh"

cat > "$CYBRA/modules/module_152_rollback_evo/main.sh" <<'RBEOF'
#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 152: Відкат до чистої ноти EVO
CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/rollback_evo.log"
mkdir -p "$CYBRA/logs"

rollback_status() {
    echo ""
    echo "— Поточний стан —"
    [ -d "$CYBRA/.git" ] && echo "Git: $(cd "$CYBRA" && git rev-parse --short HEAD 2>/dev/null)"
    echo "EVO: $([ -f "$CYBRA/evo/evo_core.py" ] && echo 'є' || echo 'немає')"
    echo "Sandbox: $([ -d "$CYBRA/sandbox" ] && echo 'є' || echo 'немає')"
}
rollback_do() {
    echo ""
    read -r -p "Підтвердити відкат? (yes/no): " ok
    [ "$ok" != "yes" ] && echo "скасовано" && return
    [ -d "$CYBRA/.git" ] && (cd "$CYBRA" && git reset --hard HEAD --quiet 2>/dev/null) || true
    echo "✅ Відкат виконано"
    echo "[$(date -u +%FT%TZ)] ROLLBACK" >> "$LOG"
}

clear 2>/dev/null
while true; do
    echo ""
    echo "════════ 152. ВІДКАТ ДО ЧИСТОЇ НОТИ EVO ════════"
    echo "1) Стан  2) Відкат  0) Назад"
    read -r -p "Вибір: " c
    case "$c" in
        1) rollback_status ;;
        2) rollback_do ;;
        0) exit 0 ;;
        *) echo "невідомо" ;;
    esac
done
RBEOF
chmod +x "$CYBRA/modules/module_152_rollback_evo/main.sh"

# 2. Додаємо пункти в меню
if [ -f "$MENU" ]; then
    cp "$MENU" "$MENU.bak.$(date +%s)"
    python3 - <<'PYPATCH'
from pathlib import Path
import re
menu = Path.home() / "CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
text = menu.read_text()
# Додаємо блок 151/152 перед рядком "0)" (вихід)
insert = '''  ─── НОВІ (151/152) ───
  🟢 [151] Реклама (Ad Contract)
  🟢 [152] Відкат до чистої ноти EVO

'''
# Додаємо до виводу меню (перед [0])
if '[151]' not in text:
    text = text.replace('  [0]  Вихід', insert + '  [0]  Вихід')
# Додаємо обробники в case
if '151)' not in text:
    text = text.replace('        0|q|Q|exit|quit)', '        151) bash "$HOME/CYBRA/modules/module_151_ad_contract/main.sh" ;;\n        152) bash "$HOME/CYBRA/modules/module_152_rollback_evo/main.sh" ;;\n        0|q|Q|exit|quit)')
menu.write_text(text)
print("  [✓] Меню оновлено: 151, 152")
PYPATCH
else
    echo "  [!] Меню не знайдено: $MENU"
fi

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ ГОТОВО"
echo "  Тепер у меню: [151] Реклама, [152] Відкат EVO"
echo "════════════════════════════════════════════"
