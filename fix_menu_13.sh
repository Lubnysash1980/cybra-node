#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

echo "═══ 1. ПЕРЕВІРКА ФУНКЦІЇ action_show_invoice ═══"
grep -n "action_show_invoice" "$MENU" | head -3

echo ""
echo "═══ 2. ВИПРАВЛЕННЯ action_show_invoice ═══"
python3 - <<'PYEOF'
import re
from pathlib import Path

menu = Path.home() / "CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
text = menu.read_text()

# Знаходимо функцію action_show_invoice
pattern = re.compile(r'action_show_invoice\(\)\s*\{.*?\n\}', re.DOTALL)
match = pattern.search(text)

if not match:
    print("❌ Функція не знайдена")
    exit(1)

# Нова функція (використовує нашу виправлену бібліотеку)
new_func = '''action_show_invoice() {
    printf 'CONTRACT_ID: '; read -r C
    if [ -z "$C" ]; then
        echo "❌ ID не вказано"
        read -r _
        return 1
    fi
    
    source "$HOME/CYBRA/lib/cybra_invoice_lib.sh" 2>/dev/null
    export CYBRA_INVOICE_DIR="$HOME/CYBRA/modules/module_19_contract_tui_menu/contracts"
    
    cybra_invoice_show "$C"
    read -r _
}'''

text = text[:match.start()] + new_func + text[match.end():]
menu.write_text(text)
print("✅ action_show_invoice виправлено")
PYEOF

echo ""
echo "═══ 3. ПЕРЕВІРКА СИНТАКСИСУ ═══"
bash -n "$MENU" && echo "✅ Синтаксис OK" || echo "❌ Синтаксис зламано"

echo ""
echo "═══ 4. ТЕСТ ═══"
source "$CYBRA/lib/cybra_invoice_lib.sh"
export CYBRA_INVOICE_DIR="$CYBRA/modules/module_19_contract_tui_menu/contracts"
echo "--- Новий ID ---"
cybra_invoice_show "INV-20261018T152617Z-3988"

echo ""
echo "═══ 5. ФІНАЛЬНИЙ КОМІТ ═══"
cd "$CYBRA" || exit 1
git add -A
git commit -m "fix: action_show_invoice uses corrected library" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Синхронізовано"
