#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
CONTRACTS="$CYBRA/modules/module_19_contract_tui_menu/contracts"

echo "═══ 1. ЩО ЛЕЖИТЬ У ПАПЦІ КОНТРАКТІВ ═══"
ls -la "$CONTRACTS" | head -20

echo ""
echo "═══ 2. СКІЛЬКИ ФАЙЛІВ КОЖНОГО ТИПУ ═══"
echo "JSON: $(ls "$CONTRACTS"/*.json 2>/dev/null | wc -l)"
echo "ENV:  $(ls "$CONTRACTS"/*.env 2>/dev/null | wc -l)"

echo ""
echo "═══ 3. ЯК ПРАЦЮЄ ПУНКТ [2] У МЕНЮ ═══"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
grep -n -A5 "action_list_contracts" "$MENU" | head -10

echo ""
echo "═══ 4. ПЕРШІ 5 JSON-ФАЙЛІВ ═══"
ls "$CONTRACTS"/*.json 2>/dev/null | head -5 | while read f; do
    echo "  $(basename "$f")"
done
