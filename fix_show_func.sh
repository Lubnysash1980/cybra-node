#!/data/data/com.termux/files/usr/bin/bash
LIB="$HOME/CYBRA/lib/cybra_invoice_lib.sh"

echo "═══ ВИПРАВЛЕННЯ ФУНКЦІЇ cybra_invoice_show ═══"

# Замінюємо функцію через Python (щоб уникнути проблем з екрануванням)
python3 - <<'PYEOF'
from pathlib import Path

lib = Path.home() / "CYBRA/lib/cybra_invoice_lib.sh"
text = lib.read_text()

# Знаходимо початок і кінець функції cybra_invoice_show
import re
pattern = re.compile(r'cybra_invoice_show\(\)\s*\{.*?\n\}', re.DOTALL)
match = pattern.search(text)

if not match:
    print("❌ Функція не знайдена")
    exit(1)

# Нова надійна функція
new_func = '''cybra_invoice_show() {
    local id="$1"
    if [ -z "$id" ]; then
        echo "❌ ID не вказано"
        return 1
    fi
    
    local file="$CYBRA_INVOICE_DIR/${id}.json"
    if [ ! -f "$file" ]; then
        echo "❌ Файл не знайдено: $file"
        return 1
    fi
    
    /data/data/com.termux/files/usr/bin/python3 -c "
import json, sys
try:
    inv = json.load(open('$file'))
    t = inv['totals']
    print('=' * 60)
    print(f\\\"  РАХУНОК № {inv.get('number', '?')} від {inv.get('date', '?')}\\\")
    print('=' * 60)
    print(f\\\"  ID: {inv.get('id', '?')}\\\")
    print(f\\\"  Статус: {inv.get('status', '?')}\\\")
    print(f\\\"  Покупець: {inv.get('buyer', {}).get('name', '?')}\\\")
    print(f\\\"  Продавець: {inv.get('seller', {}).get('name', '?')}\\\")
    print('-' * 60)
    for i, it in enumerate(inv.get('items', []), 1):
        print(f\\\"  {i}. {it.get('name', '?')} x{it.get('qty', 0)} = {it.get('line_total', 0):.2f} грн\\\")
    print('-' * 60)
    print(f\\\"  Сума без ПДВ: {t.get('sum_without_vat', 0):>10.2f} грн\\\")
    print(f\\\"  ПДВ:          {t.get('vat', 0):>10.2f} грн\\\")
    print(f\\\"  ВСЬОГО:       {t.get('sum_with_vat', 0):>10.2f} грн\\\")
    print('=' * 60)
except Exception as e:
    print(f'❌ Помилка: {e}')
    sys.exit(1)
"
}'''

# Замінюємо
text = text[:match.start()] + new_func + text[match.end():]
lib.write_text(text)
print("✅ Функцію cybra_invoice_show виправлено")
PYEOF

echo ""
echo "═══ ПЕРЕВІРКА ═══"
source "$LIB"
export CYBRA_INVOICE_DIR="$HOME/CYBRA/modules/module_19_contract_tui_menu/contracts"
echo "--- Тест нового ID ---"
cybra_invoice_show "INV-20261018T152617Z-3988"
