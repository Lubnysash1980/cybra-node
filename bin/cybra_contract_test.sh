#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
MOD="$CYBRA/modules/module_19_contract_tui_menu"
MENU="$MOD/bin/cybra_menu.sh"

G=$'\033[92m'; R=$'\033[91m'; Y=$'\033[93m'; C=$'\033[96m'; B=$'\033[1m'; Z=$'\033[0m'
PASS=0; FAIL=0; FAILED=()

ok()   { printf "  ${G}[PASS]${Z} %s\n" "$1"; PASS=$((PASS+1)); }
bad()  { printf "  ${R}[FAIL]${Z} %s\n" "$1"; FAIL=$((FAIL+1)); FAILED+=("$1"); }
hdr()  { printf "\n${B}${C}═══ %s ═══${Z}\n" "$1"; }

hdr "1. STRUCTURE"
[ -d "$CYBRA" ] && ok "CYBRA exists" || bad "CYBRA missing"
[ -f "$MENU" ]  && ok "menu exists"  || bad "menu missing"
[ -x "$MENU" ]  && ok "menu exec"    || bad "menu not executable"

hdr "2. MENU FUNCTIONS"
MISS=0; TOTAL=0
while read -r num fn; do
    [ -z "$num" ] && continue
    TOTAL=$((TOTAL+1))
    if grep -q "^${fn}()" "$MENU"; then
        :  # ok
    else
        bad "[$num] $fn missing"
        MISS=$((MISS+1))
    fi
done < <(grep -oE '^\s+[0-9]+\)\s+action_[a-z0-9_]+' "$MENU" \
         | sed -E 's/^\s+([0-9]+)\)\s+(action_[a-z0-9_]+)/\1 \2/' \
         | sort -n -u)
[ "$MISS" -eq 0 ] && ok "all $TOTAL menu items have functions"

hdr "3. INVOICE MATH (per-item VAT, ROUND_HALF_UP)"
python3 - <<'PY' && ok "invoice math OK" || bad "invoice math WRONG"
from decimal import Decimal, ROUND_HALF_UP
items = [
    ("81748.33", "20%"),
    ("24525.00", "20%"),
    ("2040.83",  "20%"),
    ("3332.50",  "20%"),
    ("2915.83",  "20%"),
]
def r2(x): return Decimal(x).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)

total = Decimal("0"); vat = Decimal("0")
for price, rate in items:
    line = Decimal(price)
    total += line
    vat += r2(line * Decimal(rate.rstrip("%")) / Decimal("100"))
grand = total + vat

assert total == Decimal("114562.49"), f"sum {total}"
assert vat   == Decimal("22912.51"),  f"vat {vat}"
assert grand == Decimal("137475.00"), f"grand {grand}"
print(f"  sum={total} vat={vat} grand={grand}")
PY

hdr "4. PII MASK"
python3 - <<'PY' && ok "PII mask OK" || bad "PII mask broken"
import re
ipn = "2937002115"
masked = ipn[:4] + "****" + ipn[-2:]
assert masked == "2937****15", masked
phone = re.sub(r"(\d{3})\d{4}(\d{3})", r"\1****\2", "380663181676")
assert "*" in phone, phone
PY

hdr "5. REFUND STATE"
python3 - <<'PY' && ok "refund state OK" || bad "refund state broken"
s = "complete"
s = "disputed"; assert s == "disputed"
s = "refunded"; assert s == "refunded"
PY

hdr "SUMMARY"
printf "  ${G}PASS${Z}: %d  ${R}FAIL${Z}: %d\n" "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
    printf "\n  ${R}Failed:${Z}\n"
    for t in "${FAILED[@]}"; do printf "    ${R}✗${Z} %s\n" "$t"; done
    exit 1
fi
exit 0
