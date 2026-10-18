#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
FILE="$CYBRA/modules/module_19_contract_tui_menu/contracts/INV-20261018T152617Z-3988.json"

echo "═══ 1. ОТРИМАННЯ ЖИВОГО КУРСУ ═══"

# Спробуємо отримати курс CYBRA з CoinGecko (якщо є)
# Якщо ні — ставимо заглушку
CYBRA_USD=$(curl -s "https://api.coingecko.com/api/v3/simple/price?ids=cybra&vs_currencies=usd" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('cybra',{}).get('usd',0))" 2>/dev/null)

if [ -z "$CYBRA_USD" ] || [ "$CYBRA_USD" = "0" ]; then
    echo "  ⚠️ API не відповідає. Використовуємо тестовий курс."
    CYBRA_USD=3800.00
fi

# Курс USD → UAH (можна брати з НБУ, але поки тестовий)
USD_UAH=$(curl -s "https://bank.gov.ua/NBUStatService/v1/statdirectory/exchange?valcode=USD&json" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)[0]['rate'])" 2>/dev/null)

if [ -z "$USD_UAH" ]; then
    echo "  ⚠️ НБУ не відповідає. Використовуємо 41.50."
    USD_UAH=41.50
fi

RATE_CYBRA_UAH=$(python3 -c "print($CYBRA_USD * $USD_UAH)")

echo "  1 CYBRA = $CYBRA_USD USD"
echo "  1 USD = $USD_UAH UAH"
echo "  → 1 CYBRA = $RATE_CYBRA_UAH UAH"

echo ""
echo "═══ 2. РОЗРАХУНОК ДЛЯ INVOICE ═══"

python3 - "$FILE" "$RATE_CYBRA_UAH" "$CYBRA_USD" "$USD_UAH" <<'PY'
import json, sys
from decimal import Decimal, ROUND_HALF_UP

file_ = sys.argv[1]
rate_uah = Decimal(sys.argv[2])
cybra_usd = Decimal(sys.argv[3])
usd_uah = Decimal(sys.argv[4])

d = json.load(open(file_))
sum_uah = Decimal("137475.00")
sum_cybra = (sum_uah / rate_uah).quantize(Decimal("0.00000001"), rounding=ROUND_HALF_UP)

d["totals"]["rate_cybra_usd"] = float(cybra_usd)
d["totals"]["usd_uah"] = float(usd_uah)
d["totals"]["rate_cybra_uah"] = float(rate_uah)
d["totals"]["payment_amount_cybra"] = float(sum_cybra)
d["totals"]["rate_updated_at"] = "live" # можна додати timestamp

json.dump(d, open(file_, "w", encoding="utf-8"), indent=2, ensure_ascii=False)

print(f"  Сума: {sum_uah} грн")
print(f"  До сплати: {sum_cybra} CYBRA")
print(f"  (1 CYBRA = {rate_uah:.2f} грн)")
PY

echo ""
echo "═══ 3. ПЕРЕВІРКА ═══"
python3 - "$FILE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
t = d["totals"]
print("=" * 55)
print(f"  Рахунок № {d['number']}")
print(f"  Статус: {d['status']}")
print(f"  Сума: {t['sum_uah']:.2f} грн")
print(f"  До сплати: {t['payment_amount_cybra']:.8f} CYBRA")
print(f"  Курс: 1 CYBRA = {t['rate_cybra_uah']:.2f} грн")
print("=" * 55)
PY
