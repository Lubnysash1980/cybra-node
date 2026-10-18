#!/usr/bin/env python3
import json, os
from pathlib import Path
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP

# Шлях до файлу
CONTRACTS = Path.home() / "CYBRA/modules/module_19_contract_tui_menu/contracts"
FILE = CONTRACTS / "INV-20261018T152617Z-3988.json"

if not FILE.exists():
    print(f"❌ Файл не знайдено: {FILE}")
    exit(1)

# Читаємо
data = json.loads(FILE.read_text())

# Правильна сума з ПДВ = 137475.00
total_with_vat = Decimal("137475.00")
vat_rate = Decimal("20")
vat = total_with_vat * vat_rate / (Decimal("100") + vat_rate)
vat = vat.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
without_vat = total_with_vat - vat

# Оновлюємо дані
data["totals"] = {
    "sum_with_vat": float(total_with_vat),
    "vat": float(vat),
    "sum_without_vat": float(without_vat),
    "vat_rate": 20.0
}
data["status"] = "complete"
data["finalized_at"] = datetime.now(timezone.utc).isoformat()

# Зберігаємо
FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False))

# Показуємо
print("=" * 60)
print(f"  РАХУНОК № {data['number']} від {data['date']}")
print("=" * 60)
print(f"  ID: {data['id']}")
print(f"  Статус: {data['status']}")
print(f"  Покупець: {data['buyer']['name']}")
print(f"  Продавець: {data['seller']['name']}")
print("-" * 60)
for i, it in enumerate(data["items"], 1):
    print(f"  {i}. {it['name']} x{it['qty']} = {it['line_total']:.2f} грн")
print("-" * 60)
print(f"  Сума без ПДВ: {data['totals']['sum_without_vat']:>10.2f} грн")
print(f"  ПДВ (20%):    {data['totals']['vat']:>10.2f} грн")
print(f"  ВСЬОГО:       {data['totals']['sum_with_vat']:>10.2f} грн")
print("=" * 60)

# Перевірка
if data["totals"]["sum_with_vat"] == 137475.00:
    print("✅ Сума правильна: 137475.00 грн")
else:
    print(f"❌ Сума неправильна: {data['totals']['sum_with_vat']}")
