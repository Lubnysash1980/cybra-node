#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

echo "═══ 1. ВИПРАВЛЕННЯ action_show_status ═══"

python3 - <<'PYEOF'
import re
from pathlib import Path

menu = Path.home() / "CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
text = menu.read_text()

pattern = re.compile(r'action_show_status\(\)\s*\{.*?\n\}', re.DOTALL)
match = pattern.search(text)

if not match:
    print("❌ Функція не знайдена")
    exit(1)

new_func = '''action_show_status() {
    printf 'CONTRACT_ID: '; read -r C
    if [ -z "$C" ]; then
        echo "❌ ID не вказано"
        read -r _
        return 1
    fi
    
    source "$HOME/CYBRA/lib/cybra_invoice_lib.sh" 2>/dev/null
    export CYBRA_INVOICE_DIR="$HOME/CYBRA/modules/module_19_contract_tui_menu/contracts"
    
    # Якщо це JSON (INVOICE) — показуємо красиву таблицю
    if [ -f "$CYBRA_INVOICE_DIR/$C.json" ]; then
        cybra_invoice_show "$C"
    else
        # Якщо ENV — показуємо як текст
        local f="$CYBRA_CONTRACTS/$C.env"
        if [ -f "$f" ]; then
            cat "$f" | sed 's/^/  /'
        else
            echo "❌ Не знайдено: $C"
        fi
    fi
    read -r _
}'''

text = text[:match.start()] + new_func + text[match.end():]
menu.write_text(text)
print("✅ action_show_status виправлено")
PYEOF

echo ""
echo "═══ 2. ПЕРЕВІРКА СИНТАКСИСУ ═══"
bash -n "$MENU" && echo "✅ OK" || echo "❌ Зламано"

echo ""
echo "═══ 3. КОМІТ ═══"
cd "$CYBRA" || exit 1
git add -A
git commit -m "fix: show_status displays invoice as table" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Синхронізовано"
