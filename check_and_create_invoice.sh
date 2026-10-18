#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
CONTRACTS="$CYBRA/modules/module_19_contract_tui_menu/contracts"

echo "═══ 1. ПОШУК РАХУНКУ РБ0518-00742 ═══"

# Шукаємо файли, де згадується номер або сума
FOUND=$(grep -rl "РБ0518-00742" "$CONTRACTS" 2>/dev/null | head -1)

if [ -z "$FOUND" ]; then
    # Шукаємо за сумою 137475
    FOUND=$(grep -rl "137475" "$CONTRACTS" 2>/dev/null | head -1)
fi

if [ -n "$FOUND" ]; then
    echo "  [✓] Знайдено: $FOUND"
    echo ""
    echo "--- ВМІСТ ---"
    cat "$FOUND"
    echo ""
    echo "--- СТАТУС ---"
    python3 -c "import json; d=json.load(open('$FOUND')); print(f\"Статус: {d.get('status','?')}\")"
else
    echo "  [!] Рахунок не знайдено. Створюємо заново..."
    
    # Створюємо через бібліотеку
    source "$CYBRA/lib/cybra_invoice_lib.sh"
    export CYBRA_INVOICE_DIR="$CONTRACTS"
    
    # Дані з рахунку
    ID=$(cybra_contract_create_invoice \
        "Грабовський Олександр Миколайович" \
        "2937002115" \
        "0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F" \
        'ТОВ "КОМФІ ТРЕЙД"' \
        "36962487" \
        "" \
        "РБ0518-00742" \
        "06.10.2026" \
        "137475.00" \
        "CYBRA" 18 20)
    
    echo "  [✓] Створено: $ID"
    
    # Додаємо 5 позицій
    cybra_invoice_add_line "$ID" "3984343" "Samsung Galaxy Fold 8 16/1Tb Graphite" 1 81748.33
    cybra_invoice_add_line "$ID" "3909742" "Послуга Comfy Upgrade 2 роки" 1 24525.00
    cybra_invoice_add_line "$ID" "2908219" "Samsung Trio 65W 2 Type-C+USB Black" 1 2040.83
    cybra_invoice_add_line "$ID" "3799926" "Pitaka Aramid Fiber Magnetic Qi2 5000mAh" 1 3332.50
    cybra_invoice_add_line "$ID" "4061288" "Pitaka Edge Ultra-Slim Case Z Fold 8" 1 2915.83
    
    echo "  [✓] Додано 5 позицій"
    
    # Показуємо
    echo ""
    echo "--- СТВОРЕНИЙ INVOICE ---"
    cybra_invoice_show "$ID"
    
    # Підписуємо (продавець = покупець, бо це тест)
    echo ""
    echo "--- ПІДПИС ПРОДАВЦЯ ---"
    TOKEN=$(python3 -c "import json; print(json.load(open('$CONTRACTS/$ID.json')).get('sign_token',''))")
    cybra_invoice_sign_seller "$TOKEN" "0x29fA26FC5768Fe1E62160E021Fd3f88d92257A1F"
    
    # Фіналізуємо
    echo ""
    echo "--- ФІНАЛІЗАЦІЯ ---"
    cybra_invoice_finalize "$ID"
    
    echo ""
    echo "  [✓] Готово! ID: $ID"
fi

echo ""
echo "═══ 2. ПЕРЕВІРКА ВСІХ INVOICE ═══"
ls -la "$CONTRACTS"/*.json 2>/dev/null | wc -l | xargs echo "Всього JSON файлів:"

echo ""
echo "--- Останні 5 ---"
ls -t "$CONTRACTS"/*.json 2>/dev/null | head -5 | while read f; do
    echo "  $(basename "$f")"
    python3 -c "import json; d=json.load(open('$f')); print(f\"    № {d.get('number','?')} | {d.get('totals',{}).get('sum_with_vat',0)} грн | {d.get('status','?')}\")" 2>/dev/null
done
