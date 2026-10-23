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
        "general_conditions": {"type": "Red Book", "engineer": "TBD", "employer": "TBD", "contractor": "TBD"},
        "particular_conditions": {},
        "boq": [],
        "payment_terms": {"currency": "UAH", "advance_percent": 10, "retention_percent": 5}
    }
    (FIDIC_DIR / f"{cid}.json").write_text(json.dumps(contract, indent=2, ensure_ascii=False))
    print(f"✅ Створено чернетку FIDIC контракту: {cid}")

if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "create":
        create_fidic_draft(sys.argv[2])
