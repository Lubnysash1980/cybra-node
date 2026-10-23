#!/usr/bin/env python3
import os, sys, json, time
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
FIDIC_DIR = CYBRA / "data" / "fidic"
FIDIC_DIR.mkdir(parents=True, exist_ok=True)

def create_fidic_draft(cid):
    contract = {
        "fidic_cid": cid,
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "state": "DRAFT",
        "general_conditions": {"type": "Red Book", "employer": "TBD", "contractor": "TBD"},
        "boq": [],
        "payment_terms": {
            "currency": "UAH",
            "milestones": [
                {"name": "Advance Payment", "percent": 30, "status": "pending"},
                {"name": "Milestone 1", "percent": 40, "status": "pending"},
                {"name": "Final Acceptance", "percent": 30, "status": "pending"}
            ]
        }
    }
    (FIDIC_DIR / f"{cid}.json").write_text(json.dumps(contract, indent=2, ensure_ascii=False))
    print(f"✅ Створено FIDIC контракт: {cid} (з етапами оплати)")

def validate_contract(cid):
    print(f"⏳ Перевірка контракту: {cid}...")
    file_path = FIDIC_DIR / f"{cid}.json"
    if not file_path.exists():
        print("❌ Контракт не знайдено"); return
    
    contract = json.loads(file_path.read_text())
    errors = []
    
    if contract["general_conditions"].get("employer") == "TBD":
        errors.append("Не вказано Замовника")
    if contract["general_conditions"].get("contractor") == "TBD":
        errors.append("Не вказано Підрядника")
        
    if len(contract.get("boq", [])) == 0:
        errors.append("Кошторис (BOQ) порожній")
        
    # Перевірка етапів оплати
    milestones = contract.get("payment_terms", {}).get("milestones", [])
    total_percent = sum(m.get("percent", 0) for m in milestones)
    if total_percent != 100:
        errors.append(f"Сума етапів оплати має бути 100% (зараз {total_percent}%)")

    if errors:
        print("🚨 ЗНАЙДЕНО ПОМИЛКИ:")
        for e in errors: print(f"  - {e}")
        contract["state"] = "BOQ_READY"
    else:
        print("✅ Всі перевірки пройдено! Контракт валідний.")
        contract["state"] = "VALIDATED"
        
    file_path.write_text(json.dumps(contract, indent=2, ensure_ascii=False))
    print(f"✅ Статус: {contract['state']}")

if __name__ == "__main__":
    if len(sys.argv) > 2:
        if sys.argv[1] == "create": create_fidic_draft(sys.argv[2])
        elif sys.argv[1] == "validate": validate_contract(sys.argv[2])
