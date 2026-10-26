#!/usr/bin/env python3
"""Генератор частина 1: SPEC_MAP + шаблони."""
SPEC_MAP = {
    1:("auto_executor","contract","create","bin/cybra_contract_cli.sh"),
    2:("contract_builder","contract","list","bin/cybra_contract_cli.sh"),
    3:("escrow_controller","contract","show","bin/cybra_contract_cli.sh"),
    4:("generate_links","contract","links","bin/cybra_contract_cli.sh"),
    5:("confirm_link","contract","confirm","bin/cybra_contract_cli.sh"),
    6:("debug","system","debug","bin/cybra_health.sh"),
    7:("dual_license","license","ledger",""),
    8:("creation_license","license","ledger",""),
    9:("hardening","system","hardening","bin/cybra_health.sh"),
    10:("invoice_sign","invoice","sign","bin/cybra_invoice_cli.sh"),
    11:("invoice_create","invoice","create","bin/cybra_invoice_cli.sh"),
    12:("invoice_add_line","invoice","add_line","bin/cybra_invoice_cli.sh"),
    13:("invoice_show","invoice","show","bin/cybra_invoice_cli.sh"),
    14:("invoice_finalize","invoice","finalize","bin/cybra_invoice_cli.sh"),
    15:("pii_export_masked","pii","export",""),
    16:("pii_export_all","pii","export_all",""),
    17:("pii_verify","pii","verify",""),
    18:("refund_decision","refund","decide",""),
    19:("refund_timeout","refund","timeout",""),
    20:("refund_status","refund","status",""),
    21:("refund_condition","refund","add",""),
    22:("rates","currency","list",""),
    23:("rates_update","currency","update",""),
    24:("currency_convert","currency","convert",""),
    25:("address_book","address","list",""),
    26:("qr_codes","qr","generate",""),
    27:("telegram_bot","telegram","setup",""),
    28:("export","export","csv",""),
    29:("backup","backup","local",""),
    30:("preflight","system","check","bin/cybra_health.sh"),
    31:("self_heal","system","heal","bin/cybra_health.sh"),
    32:("dual_backend","system","verify",""),
    33:("ownership_scan","system","scan","bin/cybra_health.sh"),
    34:("doc_scanner","ocr","scan",""),
    35:("cybra_guardian","guardian","status",""),
    36:("auto_task_runner","system","run",""),
    37:("multisig","multisig","create",""),
    38:("timelock","timelock","list",""),
    39:("contract_validator","contract","validate",""),
    40:("ai_analyze","ai","analyze","modules/module_19_contract_tui_menu/bin/cybra_local_ai.sh"),
    41:("ai_parse_invoice","ai","parse",""),
    42:("ai_generate_terms","ai","generate",""),
    43:("ai_help","ai","help",""),
    44:("ai_free_question","ai","ask",""),
    45:("ai_task_bar","ai","bar","modules/module_19_contract_tui_menu/bin/cybra_ai_executor.sh"),
    46:("executor_full","evolution","full","bin/cybra_evo_controller.py"),
    47:("executor_scan","evolution","status",""),
    48:("executor_apply","evolution","cycle","bin/cybra_evo_controller.py"),
    49:("executor_list","evolution","status","bin/cybra_evo_controller.py"),
    50:("address_add","address","add",""),
    51:("address_list","address","list",""),
    52:("address_history","address","history",""),
    53:("qr_create","qr","create",""),
    54:("telegram_setup","telegram","setup",""),
    55:("telegram_test","telegram","test",""),
    56:("webhook_list","webhook","list",""),
    57:("webhook_add","webhook","add",""),
    58:("csv_contracts","export","contracts",""),
    59:("csv_ledger","export","ledger",""),
    60:("txt_report","export","txt",""),
    61:("backup_local","backup","local",""),
    62:("backup_cloud","backup","cloud",""),
    63:("multichain_list","multichain","list",""),
    64:("scanner_tx","multichain","scan",""),
    65:("dispute_open","dispute","open",""),
    66:("dispute_list","dispute","list",""),
    67:("dispute_vote","dispute","vote",""),
    68:("audit_log","audit","log",""),
    69:("audit_verify","audit","verify",""),
    70:("ocr_photo","ocr","photo",""),
    71:("ocr_text","ocr","text",""),
    72:("pdf_to_text","ocr","pdf",""),
    73:("ocr_pipeline","ocr","pipeline",""),
    74:("contract_search","contract","search",""),
    75:("contract_autofill","contract","autofill",""),
    76:("ai_terms_run","ai","terms",""),
    77:("payment_check","payment","check",""),
    78:("contract_extra_terms","contract","extra",""),
    79:("watchdog","system","watchdog",""),
    80:("guardian_status","guardian","status",""),
    81:("guardian_100pct","guardian","check",""),
    82:("register_identity","identity","register",""),
    83:("show_identity","identity","show",""),
    84:("verify_identity","identity","verify",""),
    85:("device_info","device","info",""),
    86:("snapshot_create","snapshot","create",""),
    87:("snapshot_git_restore","snapshot","git",""),
    88:("snapshot_restore","snapshot","restore",""),
    89:("auto_recovery","guardian","recover",""),
    90:("action_log","audit","action",""),
    91:("log_verify","audit","verify",""),
    92:("autosave_contract","autosave","save",""),
    93:("autosave_status","autosave","status",""),
    94:("autosave_archives","autosave","list",""),
    95:("autosave_restore","autosave","restore",""),
    96:("evo7","evolution","level","bin/cybra_evo_controller.py"),
    97:("evo_controller","evolution","status","bin/cybra_evo_controller.py"),
    98:("parawatch","parawatch","status","bin/cybra_parawatch"),
    99:("autopatch","system","patch","bin/cybra_autopilot.py"),
    100:("node_manager","node","status","bin/cybra_node.sh"),
    101:("hash_ecosystem","hash","status",""),
    102:("binmix","system","status","bin/cybra_binmix"),
    103:("metrics","metrics","show",""),
    104:("http_panel","system","panel",""),
    105:("schedule","schedule","list",""),
    106:("cleanup","system","cleanup","bin/cybra_autopilot.py"),
    107:("autopilot","system","cycle","bin/cybra_autopilot.py"),
    108:("metamask_sign","metamask","sign",""),
    109:("metamask_verify","metamask","verify",""),
    110:("metamask_history","metamask","history",""),
    111:("invoice","invoice","list","bin/cybra_invoice_cli.sh"),
    112:("metamask_deeplink","metamask","deeplink",""),
    113:("metamask_batch","metamask","batch",""),
    114:("autonode","node","start","bin/cybra_node.sh"),
    115:("rpc_bench","rpc","bench",""),
    116:("gas_monitor","gas","show",""),
    117:("tx_lookup","tx","lookup",""),
    118:("net_health","net","check",""),
    119:("qr_sign","qr","sign",""),
    120:("ai_guardian","ai","guardian",""),
    121:("parliament","parliament","status",""),
    122:("contract_validator_v2","contract","validate",""),
    123:("multisig_v2","multisig","create",""),
    124:("timelock_v2","timelock","list",""),
    125:("anchor","anchor","status",""),
    126:("zk","zk","prove",""),
    127:("crosschain","multichain","bridge",""),
    128:("dashboard","metrics","show",""),
    129:("voice","voice","input",""),
    130:("test_suite","test","run",""),
    131:("kyc","kyc","status",""),
    132:("compliance","compliance","check",""),
    133:("tokens","token","list",""),
    134:("discord","discord","setup",""),
    135:("walletconnect","wallet","connect",""),
    136:("templates","contract","template",""),
    137:("escrow","escrow","create",""),
    138:("arbitration","dispute","arb",""),
    139:("reputation","reputation","show",""),
    140:("analytics","analytics","show",""),
    141:("portfolio","portfolio","show",""),
    142:("invoice_pdf","invoice","pdf","bin/cybra_invoice_cli.sh"),
    143:("email_notif","email","send",""),
    144:("lightning","lightning","status",""),
    145:("ipfs","ipfs","pin",""),
    146:("merkle_batch","merkle","batch",""),
    147:("reputation_v2","reputation","show",""),
    148:("multisig_ui","multisig","ui",""),
    149:("advanced_analytics","analytics","advanced",""),
    150:("custom_scripts","custom","list",""),
    151:("ad_contract","ad","create",""),
    152:("rollback_evo","evolution","rollback","bin/cybra_evo_controller.py"),
}
# 153-160 заповнимо generic
for n, _name, _cat in [
    (153, "checkpoint",      "system"),
    (154, "link_manager",    "integrations"),
    (155, "mining_autofix",  "mining"),
    (156, "chain_sync",      "blockchain"),
    (157, "pool_monitor",    "pool"),
    (158, "governance",      "governance"),
    (159, "reports",         "reports"),
    (160, "fidic_contracts", "fidic"),
]:
    SPEC_MAP[n] = (_name, _cat, "status", "")

MAIN_TEMPLATE = r'''#!/data/data/com.termux/files/usr/bin/bash
# module_{n:03d}: {name} ({category})
set -u
CYBRA="${{CYBRA:-$HOME/CYBRA}}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_{n:03d}.log"; mkdir -p "$(dirname "$LOG")"
log() {{ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }}
err() {{ log "ERR: $*"; echo "❌ $*" >&2; return 1; }}
trap 'err "line $LINENO rc=$?"' ERR

CLI_HINT="$CYBRA/{cli_hint}"
ACTION="${{1:-{default_action}}}"
shift $(( $# > 0 ? 1 : 0 ))
log "START module_{n:03d} action=$ACTION"

if [ -n "{cli_hint}" ] && [ -e "$CLI_HINT" ]; then
  case "$CLI_HINT" in
    *.py) python3 "$CLI_HINT" "$ACTION" "$@" ;;
    *)    bash "$CLI_HINT" "$ACTION" "$@" ;;
  esac
  rc=$?; log "DONE cli rc=$rc"; exit $rc
fi

case "$ACTION" in
  add|create|register)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name> [value]"; exit 1; fi
    VAL="${{2:-$(date +%s)}}"
    redis-cli hset "cybra:{category}:data" "$1" "$VAL" >/dev/null
    redis-cli set "cybra:{category}:$1" "$VAL" >/dev/null
    echo "✅ {category}: $1 = $VAL" ;;
  list|status|show)
    n=$(redis-cli hlen "cybra:{category}:data" 2>/dev/null || echo 0)
    echo "════ {category} (module_{n:03d}) ════"
    echo "  items: $n"
    if [ "$n" -gt 0 ]; then
      redis-cli hgetall "cybra:{category}:data" | paste - - | head -20 | sed 's/^/  /'
    fi ;;
  delete|remove)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name>"; exit 1; fi
    redis-cli hdel "cybra:{category}:data" "$1" >/dev/null
    redis-cli del "cybra:{category}:$1" >/dev/null
    echo "✅ deleted: $1" ;;
  *)
    echo "════ module_{n:03d}: {name} ════"
    echo "  action: $ACTION  category: {category}"
    echo "  hint: $0 add <name> [value] | $0 list | $0 delete <name>" ;;
esac
rc=$?; log "DONE action=$ACTION rc=$rc"; exit $rc
'''

CTRL_TEMPLATE = r'''#!/data/data/com.termux/files/usr/bin/bash
set -u
MODULE="$1"; shift
LOG="$HOME/CYBRA/logs/ctrl_{n:03d}.log"; mkdir -p "$(dirname "$LOG")"
log() {{ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }}
log "START ctrl_{n:03d} args=$#"
[ -f "$MODULE" ] || {{ log "ERR missing"; echo "❌ missing"; exit 2; }}
bash -n "$MODULE" 2>/dev/null || {{ log "ERR syntax"; echo "❌ syntax"; exit 3; }}
if [ $# -gt 0 ]; then ARGS=("$@"); else ARGS=("list"); fi
log "exec: bash $MODULE ${{ARGS[*]}}"
out=$(bash "$MODULE" "${{ARGS[@]}}" </dev/null 2>&1); rc=$?
lines=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
log "rc=$rc lines=$lines"
printf '%s\n' "$out"
if [ "$rc" -eq 0 ]; then exit 0; else log "FAIL"; exit 1; fi
'''
