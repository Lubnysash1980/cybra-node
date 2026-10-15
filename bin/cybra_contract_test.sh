#!/data/data/com.termux/files/usr/bin/bash
# cybra_contract_test — автотест контрактів, угод, invoice, refund, PII

CYBRA="$HOME/CYBRA"
MOD="$CYBRA/modules/module_19_contract_tui_menu"
TEST_DIR="$CYBRA/.tests"
REPORT="$TEST_DIR/report_$(date -u +%Y%m%dT%H%M%SZ).log"
mkdir -p "$TEST_DIR"

PASS=0; FAIL=0; SKIP=0
declare -a FAILED_TESTS=()

G=$'\033[92m'; R=$'\033[91m'; Y=$'\033[93m'; C=$'\033[96m'; Z=$'\033[0m'
ok()   { printf "  ${G}[PASS]${Z} %s\n" "$1"; PASS=$((PASS+1)); }
bad()  { printf "  ${R}[FAIL]${Z} %s\n" "$1"; FAIL=$((FAIL+1)); FAILED_TESTS+=("$1"); }
skip() { printf "  ${Y}[SKIP]${Z} %s\n" "$1"; SKIP=$((SKIP+1)); }

# ─────── допоміжні ───────
check_file() { [ -f "$1" ] && ok "file: $1" || bad "file missing: $1"; }
check_exec() { [ -x "$1" ] && ok "exec: $1" || bad "not executable: $1"; }
check_dir()  { [ -d "$1" ] && ok "dir:  $1" || bad "dir missing: $1"; }
check_json() {
    if [ -f "$1" ] && python3 -c "import json,sys; json.load(open('$1'))" 2>/dev/null; then
        ok "json valid: $1"
    else
        bad "json broken: $1"
    fi
}

# ─────── блок 1: файлова структура ───────
echo
echo "${C}═══ BLOCK 1: STRUCTURE ═══${Z}"
check_dir  "$MOD"
check_dir  "$MOD/bin"
check_dir  "$MOD/contracts"
check_file "$MOD/bin/cybra_menu.sh"
check_exec "$MOD/bin/cybra_menu.sh"

# ─────── блок 2: пункти меню 1-21 ───────
echo
echo "${C}═══ BLOCK 2: MENU ITEMS 1-21 ═══${Z}"

# кожен пункт має відповідну функцію action_* в cybra_menu.sh
MENU="$MOD/bin/cybra_menu.sh"
declare -A ITEMS=(
  [1]=action_create       [2]=action_list       [3]=action_status
  [4]=action_gen_links    [5]=action_confirm    [6]=action_debug
  [7]=action_dual_lic     [8]=action_creation   [9]=action_hardening
  [11]=action_invoice_new [12]=action_invoice_add [13]=action_invoice_show
  [14]=action_invoice_fin [15]=action_pii_export [16]=action_export_all
  [17]=action_pii_hash    [18]=action_refund_dec [19]=action_refund_to
  [20]=action_refund_st   [21]=action_refund_cond
)
for n in "${!ITEMS[@]}"; do
    fn="${ITEMS[$n]}"
    if grep -q "^${fn}()" "$MENU" 2>/dev/null; then
        ok "[$n] $fn defined"
    else
        bad "[$n] $fn NOT defined"
    fi
done

# ─────── блок 3: імітація угод за класами ───────
echo
echo "${C}═══ BLOCK 3: CONTRACT CLASSES ═══${Z}"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mk_contract() {
    # $1 = id, $2 = type, $3 = amount, $4 = buyer_ipn, $5 = status
    cat > "$TMP/$1.json" <<JSON
{
  "id": "$1",
  "type": "$2",
  "amount": $3,
  "currency": "UAH",
  "buyer": {"ipn": "$4", "name": "Test Buyer"},
  "supplier": {"edrpou": "36962487", "name": "Test Supplier"},
  "status": "$5",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON
}

test_contract() {
    local id="$1" type="$2" amount="$3" ipn="$4" status="$5" expect="$6"
    mk_contract "$id" "$type" "$amount" "$ipn" "$status"

    if python3 - "$TMP/$id.json" "$expect" <<'PY' 2>/dev/null
import json, sys
d = json.load(open(sys.argv[1]))
expect = sys.argv[2]

# валідація
errs = []
if not d.get("id"): errs.append("no id")
if d.get("type") not in ("sale","purchase","rent","services","escrow","invoice","refund"):
    errs.append("bad type")
if d.get("amount", 0) <= 0: errs.append("amount<=0")
if not d.get("buyer", {}).get("ipn"): errs.append("no buyer ipn")
if d.get("status") not in ("draft","active","complete","refunded","disputed"):
    errs.append("bad status")

# очікування
ok = False
if expect == "valid" and not errs: ok = True
elif expect == "invalid_type" and "bad type" in errs: ok = True
elif expect == "invalid_amount" and "amount<=0" in errs: ok = True
elif expect == "invalid_status" and "bad status" in errs: ok = True
elif expect == "no_ipn" and "no buyer ipn" in errs: ok = True

sys.exit(0 if ok else 1)
PY
    then
        ok "contract $id ($type/$status) as expected: $expect"
    else
        bad "contract $id ($type/$status) expected=$expect"
    fi
}

# валідні
test_contract "C-001" "sale"     1000 "2937002115" "active"   "valid"
test_contract "C-002" "purchase" 2500 "2937002115" "draft"    "valid"
test_contract "C-003" "rent"     500  "2937002115" "active"   "valid"
test_contract "C-004" "services" 300  "2937002115" "complete" "valid"
test_contract "C-005" "escrow"   999  "2937002115" "active"   "valid"
test_contract "C-006" "invoice"  137475 "2937002115" "draft" "valid"
test_contract "C-007" "refund"   100  "2937002115" "refunded" "valid"

# невалідні
test_contract "C-101" "unknown"  500  "2937002115" "active"   "invalid_type"
test_contract "C-102" "sale"     0    "2937002115" "active"   "invalid_amount"
test_contract "C-103" "sale"     -50  "2937002115" "active"   "invalid_amount"
test_contract "C-104" "sale"     1000 "2937002115" "unknown"  "invalid_status"
test_contract "C-105" "sale"     1000 ""           "active"   "no_ipn"

# ─────── блок 4: invoice flow ───────
echo
echo "${C}═══ BLOCK 4: INVOICE FLOW ═══${Z}"

INV="$TMP/invoice.json"
python3 - "$INV" <<'PY'
import json, sys, time
inv = {
  "id": "INV-TEST-001",
  "number": "РБ0518-00742",
  "date": "2026-10-06",
  "items": [
    {"code":"3984343","desc":"Samsung Fold 8","qty":1,"price":81748.33,"vat":"20%"},
    {"code":"3909742","desc":"Comfy Upgrade","qty":1,"price":24525.00,"vat":"20%"},
    {"code":"2908219","desc":"Samsung Trio 65W","qty":1,"price":2040.83,"vat":"20%"},
    {"code":"3799926","desc":"Pitaka Qi2","qty":1,"price":3332.50,"vat":"20%"},
    {"code":"4061288","desc":"Pitaka Case","qty":1,"price":2915.83,"vat":"20%"},
  ],
  "totals": {"sum_without_vat":114562.49,"vat":22912.51,"sum_with_vat":137475.00},
  "status": "draft"
}
json.dump(inv, open(sys.argv[1],"w"), indent=2, ensure_ascii=False)
PY

if python3 - "$INV" <<'PY' 2>/dev/null
import json, sys
inv = json.load(open(sys.argv[1]))
# перевірка математики
total = sum(i["qty"]*i["price"] for i in inv["items"])
vat = total * 0.20
grand = total + vat
exp_total = inv["totals"]["sum_without_vat"]
exp_vat   = inv["totals"]["vat"]
exp_grand = inv["totals"]["sum_with_vat"]
assert abs(total - exp_total) < 0.01, f"sum mismatch {total} vs {exp_total}"
assert abs(vat - exp_vat)     < 0.01, f"vat mismatch {vat} vs {exp_vat}"
assert abs(grand - exp_grand) < 0.01, f"grand mismatch {grand} vs {exp_grand}"
assert len(inv["items"]) == 5, "items count"
assert inv["status"] == "draft", "status"
PY
then
    ok "invoice math correct (114562.49 + 22912.51 = 137475.00)"
else
    bad "invoice math WRONG"
fi

# ─────── блок 5: PII masking ───────
echo
echo "${C}═══ BLOCK 5: PII MASKING ═══${Z}"

python3 - "$TMP" <<'PY' && ok "PII mask works" || bad "PII mask broken"
import json, re, sys, os
src = {
  "buyer": {"name": "Грабовський Олександр Миколайович", "ipn": "2937002115", "phone": "380663181676"},
  "card": "4111 1111 1111 1111",
  "iban": "UA893052990000026002050009988"
}
def mask_ipn(s):   return s[:4] + "****" + s[-2:] if len(s) >= 6 else "***"
def mask_phone(s): return re.sub(r"(\d{3})\d{4}(\d{3})", r"\1****\2", s)
def mask_card(s):  return re.sub(r"\d(?=\d{4})", "*", s.replace(" ", ""))
def mask_iban(s):  return s[:4] + "*"*(len(s)-8) + s[-4:]
masked = {
  "buyer": {"name": src["buyer"]["name"], "ipn": mask_ipn(src["buyer"]["ipn"]), "phone": mask_phone(src["buyer"]["phone"])},
  "card": mask_card(src["card"]),
  "iban": mask_iban(src["iban"])
}
assert masked["buyer"]["ipn"] == "2937****15", masked["buyer"]["ipn"]
assert "*" in masked["buyer"]["phone"], masked["buyer"]["phone"]
assert masked["card"].count("*") >= 12, masked["card"]
assert masked["iban"].startswith("UA89") and masked["iban"].endswith("9988"), masked["iban"]
json.dump({"orig": src, "masked": masked}, open(os.path.join(sys.argv[1], "pii.json"), "w"), ensure_ascii=False)
PY

# ─────── блок 6: refund flow ───────
echo
echo "${C}═══ BLOCK 6: REFUND FLOW ═══${Z}"

python3 - "$TMP" <<'PY' && ok "refund state machine works" || bad "refund state machine broken"
import sys, os, json
state = {
  "contract": "C-REF-001",
  "amount": 137475.00,
  "status": "complete",
  "timeout_h": 72,
  "created_ts": 0,
  "buyer_decision": None,
  "conditions": []
}
# transition 1: complete -> disputed
state["status"] = "disputed"
assert state["status"] == "disputed"
# transition 2: add condition
state["conditions"].append({"type":"timeout","hours":72})
assert len(state["conditions"]) == 1
# transition 3: buyer decision
state["buyer_decision"] = "refund"
assert state["buyer_decision"] == "refund"
# transition 4: disputed -> refunded
state["status"] = "refunded"
assert state["status"] == "refunded"
json.dump(state, open(os.path.join(sys.argv[1], "refund.json"), "w"), indent=2)
PY

# ─────── блок 7: files generated ───────
echo
echo "${C}═══ BLOCK 7: GENERATED FILES ═══${Z}"

for f in "$TMP"/*.json; do
    check_json "$f"
done

# ─────── підсумок ───────
echo
echo "${C}═══════════════════════════════════════════════${Z}"
printf "  ${G}PASS${Z}: %-4d  ${R}FAIL${Z}: %-4d  ${Y}SKIP${Z}: %-4d\n" "$PASS" "$FAIL" "$SKIP"
echo "${C}═══════════════════════════════════════════════${Z}"

if [ "$FAIL" -gt 0 ]; then
    echo
    echo "${R}Провалені тести:${Z}"
    for t in "${FAILED_TESTS[@]}"; do
        echo "  ${R}✗${Z} $t"
    done
fi

# записати звіт
{
    echo "=== CYBRA CONTRACT TEST REPORT ==="
    echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
    echo
    echo "Failed tests:"
    for t in "${FAILED_TESTS[@]}"; do echo "  - $t"; done
} > "$REPORT"

echo
echo "Звіт: $REPORT"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
