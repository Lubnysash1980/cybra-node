#!/usr/bin/env python3
import os, subprocess, shutil
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ВСТАНОВЛЕННЯ PM2 ═══")
r = run("command -v pm2")
if not r.stdout.strip():
    print("  Встановлюємо Node.js та PM2...")
    run("pkg install -y nodejs")
    run("npm install -g pm2")
else:
    print("  [✓] pm2 вже встановлено")

print("\n═══ 2. ВІДНОВЛЕННЯ cybra_invoice_lib.sh ═══")
lib_file = CYBRA / "lib" / "cybra_invoice_lib.sh"
lib_file.parent.mkdir(exist_ok=True)

lib_content = r'''#!/data/data/com.termux/files/usr/bin/bash
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
vat = r2(amount * Decimal(20) / Decimal(120))
inv = {
    "id": file_.split("/")[-1].replace(".json", ""), "type": "invoice", "number": number, "date": date,
    "created": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "buyer": {"name": buyer, "ipn": ipn, "wallet": bw}, "seller": {"name": seller, "edrpou": edrpou, "wallet": sw},
    "token": {"symbol": token, "decimals": 18},
    "totals": {"sum_with_vat": float(amount), "vat": float(vat), "sum_without_vat": float(amount - vat), "vat_rate": 20.0},
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
    local id="$1" file="$CYBRA_INVOICE_DIR/${id}.json"
    /data/data/com.termux/files/usr/bin/python3 - "$file" <<'PY'
import json, sys
inv = json.load(open(sys.argv[1])); t = inv["totals"]
print("=" * 60); print(f"  РАХУНОК № {inv['number']} від {inv['date']}"); print("=" * 60)
print(f"  ID: {inv['id']}"); print(f"  Статус: {inv['status']}"); print(f"  Покупець: {inv['buyer']['name']}"); print(f"  Продавець:{inv['seller']['name']}"); print("-" * 60)
for i, it in enumerate(inv["items"], 1): print(f"  {i}. {it['name']} x{it['qty']} = {it['line_total']:.2f} грн")
print("-" * 60); print(f"  Сума без ПДВ: {t['sum_without_vat']:>10.2f} грн"); print(f"  ПДВ (20%):    {t['vat']:>10.2f} грн"); print(f"  ВСЬОГО:       {t['sum_with_vat']:>10.2f} грн"); print("=" * 60)
PY
}

cybra_invoice_finalize() {
    local id="$1" file="$CYBRA_INVOICE_DIR/${id}.json"
    /data/data/com.termux/files/usr/bin/python3 - "$file" <<'PY'
import json, sys, datetime
inv = json.load(open(sys.argv[1])); inv["status"] = "complete"; inv["finalized_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
json.dump(inv, open(sys.argv[1], "w", encoding="utf-8"), indent=2, ensure_ascii=False); print(f"✅ INVOICE {inv['number']} → COMPLETE")
PY
}

cybra_invoice_get_sign_link() {
    local id="$1" token=$(/data/data/com.termux/files/usr/bin/python3 -c "import json; print(json.load(open('$CYBRA_INVOICE_DIR/${id}.json')).get('sign_token',''))")
    [ -n "$token" ] && echo "cybra://sign/${token}"
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
'''
lib_file.write_text(lib_content, encoding="utf-8")
os.chmod(lib_file, 0o755)
print("  [✓] Створено cybra_invoice_lib.sh")

print("\n═══ 3. КОМІТ У GIT ═══")
r = run("git status --porcelain", cwd=str(CYBRA))
if r.stdout.strip():
    run("git add -A", cwd=str(CYBRA))
    run('git commit -m "fix: restore invoice lib for EVO main node"', cwd=str(CYBRA))
    print("  [✓] Закомічено")
else:
    print("  [i] Немає що комітити")

print("\n═══ 4. ЗАПУСК PM2 ═══")
run("pm2 delete all")
run("pm2 start ~/CYBRA/ecosystem.config.js")
run("pm2 save")
r = run("pm2 status")
print(r.stdout)

print("\n═══ 5. ТЕСТ ВІДНОВЛЕННЯ ═══")
lib_file.unlink()
print("  [✓] cybra_invoice_lib.sh видалено")
run("bash ~/CYBRA/bin/cybra_autonode_main")
if lib_file.exists():
    print("  [✓] УСПІХ! Файл відновлено.")
else:
    print("  [✗] ПРОВАЛ! Файл не відновився.")

r = run("tail -5 ~/CYBRA/logs/evo_node_main.log")
print("\nЛоги:")
print(r.stdout)
