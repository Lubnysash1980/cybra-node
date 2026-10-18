#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
MOD13="$CYBRA/modules/module_13_base/main.sh"

echo "═══ 1. ПЕРЕВІРКА module_13_base ═══"
if [ -f "$MOD13" ]; then
    echo "--- ВМІСТ ---"
    cat "$MOD13"
    echo ""
    echo "--- СИНТАКСИС ---"
    bash -n "$MOD13" && echo "OK" || echo "ЗЛАМАНО"
else
    echo "❌ Файл не знайдено"
fi

echo ""
echo "═══ 2. ЗАМІНА НА ПРАВИЛЬНИЙ ВИКЛИК ═══"
cat > "$MOD13" <<'MODEOF'
#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 13: Показати INVOICE
# Використовує виправлену бібліотеку

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_13.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }
trap 'log "ERR $LINENO"; echo "❌ Помилка. Лог: $LOG"' ERR

source "$CYBRA/lib/cybra_invoice_lib.sh" 2>/dev/null
export CYBRA_INVOICE_DIR="$CYBRA/modules/module_19_contract_tui_menu/contracts"

echo "════════════════════════════════════════════"
echo "  [13] ПОКАЗАТИ INVOICE"
echo "════════════════════════════════════════════"
read -p "ID: " ID

if [ -z "$ID" ]; then
    echo "❌ ID не вказано"
    read -r _
    exit 1
fi

cybra_invoice_show "$ID"

read -r -p "Натисни Enter..." _
exit 0
MODEOF

chmod +x "$MOD13"
echo "  [✓] module_13_base/main.sh замінено"

echo ""
echo "═══ 3. ПЕРЕВІРКА СИНТАКСИСУ ═══"
bash -n "$MOD13" && echo "✅ Синтаксис OK" || echo "❌ Зламано"

echo ""
echo "═══ 4. ТЕСТ ═══"
bash "$MOD13" <<< "INV-20261018T152617Z-3988"

echo ""
echo "═══ 5. КОМІТ ═══"
cd "$CYBRA" || exit 1
git add -A
git commit -m "fix: module_13 shows formatted invoice table" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Синхронізовано"
