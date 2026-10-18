#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
MOD13="$CYBRA/modules/module_13_base/main.sh"

echo "═══ 1. ПЕРЕЗАПИС БЕЗ TRAP (ЩОБ НЕ БУЛО ФАЛЬШИВИХ ПОМИЛОК) ═══"

cat > "$MOD13" <<'MODEOF'
#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 13: Показати INVOICE (без trap, щоб не було фальшивих помилок)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_13.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

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
log "SHOW: $ID"

read -r -p "Натисни Enter..." _
exit 0
MODEOF

chmod +x "$MOD13"
echo "  [✓] module_13_base/main.sh перезаписано (без trap)"

echo ""
echo "═══ 2. ПЕРЕВІРКА СИНТАКСИСУ ═══"
bash -n "$MOD13" && echo "✅ OK" || echo "❌ Зламано"

echo ""
echo "═══ 3. ТЕСТ ═══"
echo "INV-20261018T152617Z-3988" | bash "$MOD13"

echo ""
echo "═══ 4. КОМІТ ═══"
cd "$CYBRA" || exit 1
git add -A
git commit -m "fix: module_13 without trap (no false errors)" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Синхронізовано"
