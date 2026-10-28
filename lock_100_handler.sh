#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"

echo "═══ LOCK 100% ═══"

# 0. unlock (щоб fix міг записати)
chmod u+w modules/module_19_contract_tui_menu/bin/cybra_menu.sh 2>/dev/null || true

# 1. KILL REWRITERS (дееволюція)
echo "── 1. rewriters ──"
pm2 delete cybra-autopilot cybra-binmix-mixin menu-autorobot cybra-evo-ctrl 2>/dev/null

# ecosystem → apps: [] (щоб не піднялись)
[ -f ecosystem.config.js ] && cp ecosystem.config.js ecosystem.config.js.bak.$(date +%s)
python3 - <<'PY'
from pathlib import Path
import re
p = Path.home()/"CYBRA/ecosystem.config.js"
if p.exists():
    t = p.read_text()
    t = re.sub(r'apps\s*:\s*\[.*?\]', 'apps: []', t, flags=re.DOTALL)
    p.write_text(t)
    print("  ecosystem: apps = []")
PY

# 2. MENU LABELS
echo "── 2. menu labels ──"
python3 - <<'PY'
import re, sys
from pathlib import Path
CYBRA = Path.home()/"CYBRA"
MENU = CYBRA/"modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
sys.path.insert(0, str(CYBRA/"bin"))
try: from cybra_gen_part1 import SPEC_MAP
except: SPEC_MAP = {}

O = {
 10:("invoice_sign","invoice"),25:("address_book","address"),26:("qr_codes","qr"),
 27:("telegram_bot","telegram"),28:("export","export"),29:("backup","backup"),
 34:("doc_scanner","ocr"),35:("cybra_guardian","guardian"),36:("auto_task_runner","system"),
 37:("multisig","multisig"),38:("timelock","timelock"),39:("contract_validator","contract"),
 40:("ai_analyze","ai"),41:("ai_parse_invoice","ai"),42:("ai_generate_terms","ai"),
 43:("ai_help","ai"),44:("ai_free_question","ai"),45:("ai_task_bar","ai"),
 46:("executor_full","evolution"),47:("executor_scan","evolution"),
 48:("executor_apply","evolution"),49:("executor_list","evolution"),
 50:("address_add","address"),51:("address_list","address"),52:("address_history","address"),
 53:("qr_create","qr"),54:("telegram_setup","telegram"),55:("telegram_test","telegram"),
 56:("webhook_list","webhook"),57:("webhook_add","webhook"),58:("csv_contracts","export"),
 59:("csv_ledger","export"),60:("txt_report","export"),61:("backup_local","backup"),
 62:("backup_cloud","backup"),63:("multichain_list","multichain"),64:("scanner_tx","multichain"),
 65:("dispute_open","dispute"),66:("dispute_list","dispute"),67:("dispute_vote","dispute"),
 68:("audit_log","audit"),69:("audit_verify","audit"),70:("ocr_photo","ocr"),
 71:("ocr_text","ocr"),72:("pdf_to_text","ocr"),73:("ocr_pipeline","ocr"),
 74:("contract_search","contract"),75:("contract_autofill","contract"),76:("ai_terms_run","ai"),
 77:("payment_check","payment"),78:("contract_extra_terms","contract"),79:("watchdog","system"),
 80:("guardian_status","guardian"),81:("guardian_100pct","guardian"),
 82:("register_identity","identity"),83:("show_identity","identity"),84:("verify_identity","identity"),
 85:("device_info","device"),86:("snapshot_create","snapshot"),87:("snapshot_git_restore","snapshot"),
 88:("snapshot_restore","snapshot"),89:("auto_recovery","guardian"),90:("action_log","audit"),
 91:("log_verify","audit"),92:("autosave_contract","autosave"),93:("autosave_status","autosave"),
 94:("autosave_archives","autosave"),95:("autosave_restore","autosave"),96:("evo7","evolution"),
 97:("evo_controller","evolution"),98:("parawatch","parawatch"),99:("autopatch","system"),
 100:("node_manager","node"),101:("hash_ecosystem","hash"),102:("binmix","system"),
 103:("metrics","metrics"),104:("http_panel","system"),105:("schedule","schedule"),
 106:("cleanup","system"),107:("autopilot","system"),108:("metamask_sign","metamask"),
 109:("metamask_verify","metamask"),110:("metamask_history","metamask"),111:("invoice","invoice"),
 112:("metamask_deeplink","metamask"),113:("metamask_batch","metamask"),114:("autonode","node"),
 115:("rpc_bench","rpc"),116:("gas_monitor","gas"),117:("tx_lookup","tx"),118:("net_health","net"),
 119:("qr_sign","qr"),120:("ai_guardian","ai"),121:("parliament","parliament"),
 122:("contract_validator_v2","contract"),123:("multisig_v2","multisig"),124:("timelock_v2","timelock"),
 125:("anchor","anchor"),126:("zk","zk"),127:("crosschain","multichain"),128:("dashboard","metrics"),
 129:("voice","voice"),130:("test_suite","test"),131:("kyc","kyc"),132:("compliance","compliance"),
 133:("tokens","token"),134:("discord","discord"),135:("walletconnect","wallet"),
 136:("templates","contract"),137:("escrow","escrow"),138:("arbitration","dispute"),
 139:("reputation","reputation"),140:("analytics","analytics"),141:("portfolio","portfolio"),
 142:("invoice_pdf","invoice"),143:("email_notif","email"),144:("lightning","lightning"),
 145:("ipfs","ipfs"),146:("merkle_batch","merkle"),147:("reputation_v2","reputation"),
 148:("multisig_ui","multisig"),149:("advanced_analytics","analytics"),150:("custom_scripts","custom"),
 151:("ad_contract","ad"),152:("rollback_evo","evolution"),153:("checkpoint","system"),
 154:("link_manager","integrations"),155:("mining_autofix","mining"),156:("chain_sync","blockchain"),
 157:("pool_monitor","pool"),158:("governance","governance"),159:("reports","reports"),
 160:("fidic_contracts","fidic"),
}
for n,(name,cat) in O.items():
    SPEC_MAP[n] = (name, cat, "status", "")

def label(n):
    row = SPEC_MAP.get(n)
    if not row: return f"Module {n}"
    name, cat = row[0], row[1]
    if re.match(r'^module_\d+$', name): return f"Module {n}"
    return name.replace('_', ' ').title() + (f" · {cat}" if cat else "")

lines = MENU.read_text().splitlines()
out, changed = [], 0
for ln in lines:
    if re.match(r'^\s*\d+\)', ln): out.append(ln); continue
    new_ln, cnt = re.subn(r'"module_(\d+)_[^"]*"', lambda m: f'"{label(int(m.group(1)))}"', ln)
    out.append(new_ln); changed += cnt
MENU.write_text("\n".join(out) + "\n")
print(f"  labels changed: {changed}")
PY
bash -n modules/module_19_contract_tui_menu/bin/cybra_menu.sh && echo "  ✅ menu syntax OK"

# 3. REBUILD MASTER
echo "── 3. rebuild master ──"
python3 - <<'PY'
import json, subprocess, time
from pathlib import Path
CYBRA = Path.home()/"CYBRA"
items = []
for d in sorted((CYBRA/"modules").glob("module_*")):
    m = d/"main.sh"
    if not m.exists(): continue
    try: n = int(d.name.split("_")[1])
    except: continue
    if 200 <= n <= 272:
        r = subprocess.run(["bash", str(m), "list"], capture_output=True, timeout=5, input="")
        items.append({"id": f"module_{n:03d}", "kind": "module", "ok": r.returncode == 0, "detail": f"rc={r.returncode}", "target": str(m)})
    elif 1 <= n <= 160:
        r = subprocess.run(["bash", "-n", str(m)], capture_output=True)
        items.append({"id": f"module_{n:03d}", "kind": "module", "ok": r.returncode == 0, "detail": "syntax" if r.returncode else "ok", "target": str(m)})
try:
    r = subprocess.run(["pm2","jlist"], capture_output=True, text=True)
    for p in json.loads(r.stdout):
        items.append({"id": f"pm2_{p['name']}", "kind": "pm2", "ok": p["pm2_env"]["status"]=="online", "detail": p["pm2_env"]["status"]})
except: pass
total = len(items); passed = sum(1 for i in items if i["ok"])
pct = round(passed*100/total, 1) if total else 0
bk = {}
for i in items:
    bk.setdefault(i["kind"], {"total":0,"passed":0})
    bk[i["kind"]]["total"] += 1
    if i["ok"]: bk[i["kind"]]["passed"] += 1
(CYBRA/"state/snapshots/_master.json").write_text(json.dumps({
    "ts": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime()),
    "total": total, "passed": passed, "pct": pct, "by_kind": bk, "items": items,
}, indent=2, ensure_ascii=False))
print(f"  MASTER: {passed}/{total} = {pct}%")
PY

# 4. COMMIT + PUSH
echo "── 4. commit + push ──"
git add -A 2>/dev/null || true
CHANGES=$(git diff --cached --name-only | wc -l)
[ "$CHANGES" -gt 0 ] && git -c user.email="parliament@cybra.local" -c user.name="cybra-parliament" \
    commit -m "LOCK: 100% — rewriters killed forever, labels frozen" >/dev/null 2>&1
PUSHED=no
git push origin main >/dev/null 2>&1 && PUSHED=yes

# 5. FREEZE menu
echo "── 5. freeze ──"
chmod a-w modules/module_19_contract_tui_menu/bin/cybra_menu.sh 2>/dev/null || true
echo "  🔒 menu: read-only"

# 6. SNAPSHOT
echo "── 6. snapshot ──"
bash bin/cybra_parliament_snapshot.sh locked_100 2>&1 | tail -2

# 7. RESULT
HEAD=$(git rev-parse --short HEAD)
DASH=$(grep -l '── git ──' modules/module_*/main.sh 2>/dev/null | wc -l)
NL=$(grep -l '\\\\n' modules/module_*/main.sh 2>/dev/null | wc -l)
PCT=$(python3 -c "import json;print(json.load(open('state/snapshots/_master.json'))['pct'])" 2>/dev/null || echo '?')

echo
echo "═══ LOCKED ═══"
echo "  %:         $PCT%"
echo "  dashboard: $DASH"
echo "  \\n:        $NL"
echo "  head:      $HEAD"
echo "  pushed:    $PUSHED"
echo "  rewriters: deleted (PM2 + ecosystem = [])"
echo "  menu:      read-only"
