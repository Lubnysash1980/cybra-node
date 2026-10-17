#!/usr/bin/env python3
import os, subprocess, re
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MENU = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

# Список модулів, які мають бути (номери 108-150)
expected_modules = {
    108: "module_108_metamask_sign",
    109: "module_109_metamask_verify",
    110: "module_110_metamask_history",
    111: "module_111_invoice",       # Примітка: в меню це "metamask settings", але файл називається invoice
    112: "module_112_metamask_deeplink",
    113: "module_113_metamask_batch",
    114: "module_114_autonode",
    115: "module_115_rpc_bench",
    116: "module_116_gas_monitor",
    117: "module_117_tx_lookup",
    118: "module_118_net_health",
    119: "module_119_qr_sign",
    120: "module_120_ai_guardian",
    121: "module_121_parlament",
    122: "module_122_contract_validator",
    123: "module_123_multisig",
    124: "module_124_timelock",
    125: "module_125_anchor",
    126: "module_126_zk",
    128: "module_128_dashboard",
    129: "module_129_voice",
    130: "module_130_test_suite",
    131: "module_131_kyc",
    132: "module_132_compliance",
    133: "module_133_tokens",
    134: "module_134_discord",
    135: "module_135_walletconnect",
    136: "module_136_templates",
    137: "module_137_escrow",
    138: "module_138_arbitration",
    139: "module_139_reputation",
    140: "module_140_analytics",
    141: "module_141_portfolio",
    142: "module_142_invoice_pdf",
    143: "module_143_email",
    144: "module_144_lightning",
    145: "module_145_ipfs",
    146: "module_146_merkle",
    147: "module_147_reputation_v2",
    148: "module_148_multisig_ui",
    149: "module_149_analytics",
    150: "module_150_scripts"
}

print("═══ АУДИТ МОДУЛІВ (108–150) ═══\n")

missing = []
present = 0

for num, mod_name in sorted(expected_modules.items()):
    mod_dir = CYBRA / "modules" / mod_name
    main_sh = mod_dir / "main.sh"
    
    if main_sh.exists():
        present += 1
        print(f"  🟢 [{num}] {mod_name} — OK")
    else:
        missing.append((num, mod_name))
        print(f"  🔴 [{num}] {mod_name} — ВІДСУТНІЙ")

print(f"\n  Всього: {len(expected_modules)} | Знайдено: {present} | Відсутні: {len(missing)}")

if missing:
    print("\n═══ ВІДСУТНІ МОДУЛІ ═══")
    for num, mod_name in missing:
        print(f"  [{num}] {mod_name}")
