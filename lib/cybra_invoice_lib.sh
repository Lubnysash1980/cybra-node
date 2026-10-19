#!/data/data/com.termux/files/usr/bin/bash
CYBRA_INVOICE_DIR="${CYBRA_INVOICE_DIR:-$HOME/CYBRA/modules/module_19_contract_tui_menu/contracts}"
mkdir -p "$CYBRA_INVOICE_DIR"

cybra_contract_create_invoice() {
    local buyer="$1" ipn="$2" buyer_wallet="$3" seller="$4" edrpou="$5" seller_wallet="$6" number="$7" date="$8" amount_uah="$9" token="${10}"
    local file="$CYBRA_INVOICE_DIR/INV-$(date -u +%Y%m%dT%H%M%SZ)-$$.json"
    /data/data/com.termux/files/usr/bin/python3 - "$file" "$buyer" "$ipn" "$buyer_wallet" "$seller" "$edrpou" "$seller_wallet" "$number" "$date" "$amount_uah" "$token" <<'PY'
import json, sys, datetime, hashlib
from decimal import Decimal, ROUND_HALF_UP
def r2(x): return Decimal(str(x)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
(file_, buyer, ipn, bw, seller, edrpou, sw, number, date, amount, token) = sys.argv[1:12]
amount = Decimal(amount)
# Правильна логіка: amount - це сума З ПДВ
vat = r2(amount * Decimal(20) / Decimal(120))
without_vat = amount - vat
inv = {
    "id": file_.split("/")[-1].replace(".json", ""), "type": "invoice", "number": number, "date": date,
    "created": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "buyer": {"name": buyer, "ipn": ipn, "wallet": bw}, "seller": {"name": seller, "edrpou": edrpou, "wallet": sw},
    "token": {"symbol": token, "decimals": 18},
    "totals": {"sum_with_vat": float(amount), "vat": float(vat), "sum_without_vat": float(without_vat), "vat_rate": 20.0},
    "items": [], "sign_token": hashlib.sha256(f"{number}{date}{amount}".encode()).hexdigest()[:16],
    "status": "awaiting_seller_wallet" if not sw else "draft"
}
json.dump(inv, open(file_, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PY
    basename "$file" .json
}

cybra_invoice_add_line() {
    local id="$1" code="$2" name="$3" qty="$4" price="$5"
    local file="$CYBRA_INVOICE_DIR/${id}.json"
    /data/data/com.termux/files/usr/bin/python3 - "$file" "$code" "$name" "$qty" "$price" <<'PY'
import json, sys
from decimal import Decimal, ROUND_HALF_UP
def r2(x): return Decimal(str(x)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
file_, code, name, qty, price = sys.argv[1:6]
inv = json.load(open(file_))
q, p = Decimal(qty), Decimal(price)
line_total = r2(q * p)
line_vat = r2(line_total * Decimal(20) / Decimal(120))
inv["items"].append({"code": code, "name": name, "qty": float(q), "price": float(p), "line_total": float(line_total), "line_vat": float(line_vat)})
total_with_vat = sum(Decimal(str(i["line_total"])) for i in inv["items"])
total_vat = sum(Decimal(str(i["line_vat"])) for i in inv["items"])
inv["totals"]["sum_with_vat"] = float(r2(total_with_vat))
inv["totals"]["vat"] = float(r2(total_vat))
inv["totals"]["sum_without_vat"] = float(r2(total_with_vat - total_vat))
json.dump(inv, open(file_, "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PY
}

cybra_invoice_show() {
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
    print(f\"  РАХУНОК № {inv.get('number', '?')} від {inv.get('date', '?')}\")
    print('=' * 60)
    print(f\"  ID: {inv.get('id', '?')}\")
    print(f\"  Статус: {inv.get('status', '?')}\")
    print(f\"  Покупець: {inv.get('buyer', {}).get('name', '?')}\")
    print(f\"  Продавець: {inv.get('seller', {}).get('name', '?')}\")
    print('-' * 60)
    for i, it in enumerate(inv.get('items', []), 1):
        print(f\"  {i}. {it.get('name', '?')} x{it.get('qty', 0)} = {it.get('line_total', 0):.2f} грн\")
    print('-' * 60)
    print(f"  Сума без ПДВ: {t.get('sum_without_vat_uah', t.get('sum_without_vat', 0)):>10.2f} грн")
    print(f"  ПДВ:          {t.get('vat_uah', t.get('vat', 0)):>10.2f} грн")
    print(f"  ВСЬОГО:       {t.get('sum_uah', t.get('sum_with_vat', 0)):>10.2f} грн")
    print('=' * 60)
except Exception as e:
    print(f'❌ Помилка: {e}')
    sys.exit(1)
"
}

cybra_invoice_finalize() {
    local id="$1" file="$CYBRA_INVOICE_DIR/${id}.json"
    /data/data/com.termux/files/usr/bin/python3 - "$file" <<'PY'
import json, sys, datetime
inv = json.load(open(sys.argv[1])); inv["status"] = "complete"; inv["finalized_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
json.dump(inv, open(sys.argv[1], "w", encoding="utf-8"), indent=2, ensure_ascii=False); print(f"✅ INVOICE {inv['number']} → COMPLETE")
PY
}

cybra_invoice_sign_seller() {
    local token="$1" wallet="$2"
    /data/data/com.termux/files/usr/bin/python3 - "$CYBRA_INVOICE_DIR" "$token" "$wallet" <<'PY'
import json, sys, datetime, glob, os
dir_, token, wallet = sys.argv[1:4]
for f in glob.glob(os.path.join(dir_, "INV-*.json")):
    inv = json.load(open(f))
    if inv.get("sign_token") == token:
        inv["seller"]["wallet"] = wallet; inv["status"] = "ready_for_payment"; inv["signed_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        json.dump(inv, open(f, "w", encoding="utf-8"), indent=2, ensure_ascii=False); print(f"✅ Підписано {inv['id']}"); sys.exit(0)
print("ERROR: токен не знайдено"); sys.exit(1)
PY
}

cybra_invoice_get_sign_link() {
    local id="$1"
    local file="$CYBRA_INVOICE_DIR/${id}.json"
    if [ ! -f "$file" ]; then
        echo "ERROR: файл $id не знайдено"
        return 1
    fi
    local token=$(/data/data/com.termux/files/usr/bin/python3 -c "import json; print(json.load(open('$file')).get('sign_token',''))" 2>/dev/null)
    if [ -z "$token" ]; then
        echo "ERROR: токен не знайдено в $id"
        return 1
    fi
    echo "cybra://sign/${token}"
}
