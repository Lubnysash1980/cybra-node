#!/usr/bin/env python3
import json
import time
from pathlib import Path
from datetime import datetime

BASE_DIR = Path(__file__).parent
CONTRACTS_FILE = BASE_DIR / "contracts.json"

# Дані з рахунку
invoice_data = {
    "contract_type": "invoice",
    "document_number": "РБ0518-00742",
    "date": "2026-10-06",
    "valid_until": "2026-10-07",
    "supplier": {
        "name": "ТОВ \"КОМФІ ТРЕЙД\"",
        "edrpou": "36962487",
        "iban": "UA893052990000026002050009988",
        "bank": "АТ КБ \"ПРИВАТБАНК\"",
        "mfo": "305299",
        "ipn": "369624804639",
        "address": "49100, м. Дніпро, бул. Слави, 6 Б, кімната 413",
        "phone": "0800 303 505"
    },
    "buyer": {
        "name": "Грабовський Олександр Миколайович",
        "ipn": "2937002115",
        "phone": "380663181676"
    },
    "shipment_address": "м. Київ, Дарницький район, вулиця Мишуги Олександра, буд. 4",
    "items": [
        {"code": "3984343", "description": "Смартфон Samsung Galaxy Fold 8 16/1Tb Graphite (SM-F971BZKNSЕК)", "quantity": 1, "unit": "шт.", "vat_rate": "20%", "price_without_vat": 81748.33, "amount": 81748.33},
        {"code": "3909742", "description": "Послуга «Comfy Upgrade 2 роки»", "quantity": 1, "unit": "шт.", "vat_rate": "20%", "price_without_vat": 24525.00, "amount": 24525.00},
        {"code": "2908219", "description": "Мережевий зарядний пристрій Samsung Trio 65W 2 Type-C+USB Black (EP-T6530NBEGEU)", "quantity": 1, "unit": "шт.", "vat_rate": "20%", "price_without_vat": 2040.83, "amount": 2040.83},
        {"code": "3799926", "description": "Батарея мобільна Pitaka Aramid Fiber Magnetic Qi2 5 000mAh Sunset (PBQ2402)", "quantity": 1, "unit": "шт.", "vat_rate": "20%", "price_without_vat": 3332.50, "amount": 3332.50},
        {"code": "4061288", "description": "Чохол для смартфону Pitaka Edge Ultra-Slim Case Twill Black/Grey for Samsung Galaxy Z Fold 8 (FBWFOLD8)", "quantity": 1, "unit": "шт.", "vat_rate": "20%", "price_without_vat": 2915.83, "amount": 2915.83}
    ],
    "totals": {
        "sum_without_vat": 114562.49,
        "vat_amount": 22912.51,
        "sum_with_vat": 137475.00
    },
    "signatory": "Касир Шматова Єва Володимирівна",
    "created_at": datetime.now().isoformat() + "Z",
    "status": "created"
}

def create_contract():
    contracts = []
    if CONTRACTS_FILE.exists():
        try:
            contracts = json.loads(CONTRACTS_FILE.read_text())
        except Exception:
            contracts = []

    # Перевірка на дублікат
    for c in contracts:
        if c.get("document_number") == invoice_data["document_number"]:
            print(f"⚠️ Контракт {invoice_data['document_number']} вже існує.")
            return

    contracts.append(invoice_data)
    CONTRACTS_FILE.write_text(json.dumps(contracts, indent=2, ensure_ascii=False))
    print(f"✅ Контракт {invoice_data['document_number']} успішно створено!")
    print(f"   Сума: {invoice_data['totals']['sum_with_vat']} грн")
    print(f"   Позицій: {len(invoice_data['items'])}")

if __name__ == "__main__":
    create_contract()
