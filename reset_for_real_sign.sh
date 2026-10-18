#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
CONTRACTS="$CYBRA/modules/module_19_contract_tui_menu/contracts"
ID="INV-20261018T152617Z-3988"
FILE="$CONTRACTS/$ID.json"

echo "═══ 1. СКИДАННЯ ФАЛЬШИВОГО ПІДПИСУ ═══"
if [ -f "$FILE" ]; then
    /data/data/com.termux/files/usr/bin/python3 - "$FILE" <<'PY'
import json, sys
f = sys.argv[1]
d = json.load(open(f))
# Скидаємо статус і гаманець продавця
d["status"] = "awaiting_seller_wallet"
d["seller"]["wallet"] = ""
if "signed_at" in d: del d["signed_at"]
if "finalized_at" in d: del d["finalized_at"]
json.dump(d, open(f, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
print("✅ Статус скинуто на: awaiting_seller_wallet")
print("✅ Гаманець продавця очищено")
PY
else
    echo "❌ Файл не знайдено: $FILE"
fi

echo ""
echo "═══ 2. ГЕНЕРАЦІЯ РЕАЛЬНОГО ПОСИЛАННЯ ═══"
source "$CYBRA/lib/cybra_invoice_lib.sh"
export CYBRA_INVOICE_DIR="$CONTRACTS"

LINK=$(cybra_invoice_get_sign_link "$ID")
echo "Посилання для підпису продавцем:"
echo "  $LINK"
echo ""
echo "Передай це посилання ТОВ 'КОМФІ ТРЕЙД'."
echo "Вони відкриють його у своєму гаманці (MetaMask) і підпишуть."

echo ""
echo "═══ 3. ПЕРЕВІРКА СТАТУСУ ═══"
cybra_invoice_show "$ID"
