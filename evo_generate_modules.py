#!/usr/bin/env python3
import os
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"

# Список модулів, які треба згенерувати
modules = {
    108: "metamask_sign",
    109: "metamask_verify",
    110: "metamask_history",
    111: "invoice",
    112: "metamask_deeplink",
    113: "metamask_batch",
    114: "autonode",
    115: "rpc_bench",
    116: "gas_monitor",
    117: "tx_lookup",
    118: "net_health",
    119: "qr_sign",
    120: "ai_guardian",
    121: "parlament",
    122: "contract_validator",
    123: "multisig",
    124: "timelock",
    125: "anchor",
    126: "zk",
    128: "dashboard",
    129: "voice",
    130: "test_suite",
    131: "kyc",
    132: "compliance",
    133: "tokens",
    134: "discord",
    135: "walletconnect",
    136: "templates",
    137: "escrow",
    138: "arbitration",
    139: "reputation",
    140: "analytics",
    141: "portfolio",
    142: "invoice_pdf",
    143: "email",
    144: "lightning",
    145: "ipfs",
    146: "merkle",
    147: "reputation_v2",
    148: "multisig_ui",
    149: "analytics",
    150: "scripts"
}

print("═══ ГЕНЕРАЦІЯ МОДУЛІВ (EVO) ═══")

created = 0
for num, name in sorted(modules.items()):
    mod_dir = CYBRA / "modules" / f"module_{num}_{name}"
    main_sh = mod_dir / "main.sh"
    
    if main_sh.exists():
        print(f"  🟢 [{num}] {name} — вже існує")
        continue
    
    mod_dir.mkdir(parents=True, exist_ok=True)
    
    # Створюємо простий, але робочий main.sh
    content = f'''#!/data/data/com.termux/files/usr/bin/bash
# Модуль {num}: {name}
# Автоматично згенеровано EVO

printf '\\n\\033[96m═══ MODULE {num}: {name.upper()} ═══\\033[0m\\n'
printf '  Статус: активний (згенеровано EVO)\\n'
printf '  Функція: базовий виклик\\n'
printf '\\nНатисни Enter, щоб повернутися в меню...'
read -r _
exit 0
'''
    main_sh.write_text(content, encoding="utf-8")
    os.chmod(main_sh, 0o755)
    print(f"  🟢 [{num}] {name} — СТВОРЕНО")
    created += 1

print(f"\\n  Всього створено: {created}")
