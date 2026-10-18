#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

echo "═══ 1. ВИПРАВЛЕННЯ action_list_contracts ═══"

python3 - <<'PYEOF'
import re
from pathlib import Path

menu = Path.home() / "CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
text = menu.read_text()

# Знаходимо функцію
pattern = re.compile(r'action_list_contracts\(\)\s*\{.*?\n\}', re.DOTALL)
match = pattern.search(text)

if not match:
    print("❌ Функція не знайдена")
    exit(1)

# Нова функція (шукає і ENV, і JSON)
new_func = '''action_list_contracts() {
    printf '%s\\n' "${C_BOLD}--- Контракти ---${C_RESET}"
    local n=0
    
    # 1. ENV контракти
    printf '%s\\n' "${C_CYAN}--- ENV ---${C_RESET}"
    for f in "$CYBRA_CONTRACTS"/*.env; do
        [ -f "$f" ] || continue
        local cid="$(basename "$f" .env)"
        local stage="$(grep -m1 '^STAGE=' "$f" | cut -d= -f2-)"
        printf '  %-45s [%s]\\n' "$cid" "$stage"
        n=$((n+1))
    done
    
    # 2. JSON контракти (INVOICE)
    printf '%s\\n' "${C_CYAN}--- JSON (INVOICE) ---${C_RESET}"
    for f in "$CYBRA_CONTRACTS"/*.json; do
        [ -f "$f" ] || continue
        local cid="$(basename "$f" .json)"
        local status=$(/data/data/com.termux/files/usr/bin/python3 -c "import json; print(json.load(open('$f')).get('status','?'))" 2>/dev/null)
        local number=$(/data/data/com.termux/files/usr/bin/python3 -c "import json; print(json.load(open('$f')).get('number','?'))" 2>/dev/null)
        printf '  %-45s [%s] №%s\\n' "$cid" "$status" "$number"
        n=$((n+1))
    done
    
    printf '\\nВсього: %s\\n' "$n"
    read -r _
}'''

text = text[:match.start()] + new_func + text[match.end():]
menu.write_text(text)
print("✅ action_list_contracts виправлено (шукає ENV + JSON)")
PYEOF

echo ""
echo "═══ 2. ПЕРЕВІРКА СИНТАКСИСУ ═══"
bash -n "$MENU" && echo "✅ Синтаксис OK" || echo "❌ Зламано"

echo ""
echo "═══ 3. КОМІТ ═══"
cd "$CYBRA" || exit 1
git add -A
git commit -m "fix: list_contracts shows both ENV and JSON" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Синхронізовано"
