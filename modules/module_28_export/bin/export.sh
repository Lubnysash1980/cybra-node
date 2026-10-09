#!/data/data/com.termux/files/usr/bin/bash
EXP_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$EXP_ROOT/data"
mkdir -p "$OUT"

exp_contracts_csv() {
    local file="$OUT/contracts_$(date -u +%Y%m%d).csv"
    echo "CONTRACT_ID,CREATED,BUYER,SELLER,AMOUNT,LICENSE_A,LICENSE_B,CREATION,NET,STAGE,STATUS" > "$file"
    local dir="$HOME/CYBRA/modules/module_19_contract_tui_menu/contracts"
    for f in "$dir"/*.env; do
        [ -f "$f" ] || continue
        local cid="$(basename "$f" .env)"
        local created="$(grep -m1 '^CREATED_AT=' "$f" | cut -d= -f2-)"
        local buyer="$(grep -m1 '^BUYER=' "$f" | cut -d= -f2-)"
        local seller="$(grep -m1 '^SELLER=' "$f" | cut -d= -f2-)"
        local amount="$(grep -m1 '^AMOUNT_WEI=' "$f" | cut -d= -f2-)"
        local la="$(grep -m1 '^LICENSE_A_WEI=' "$f" | cut -d= -f2-)"
        local lb="$(grep -m1 '^LICENSE_B_WEI=' "$f" | cut -d= -f2-)"
        local cf="$(grep -m1 '^CREATION_FEE_WEI=' "$f" | cut -d= -f2-)"
        local net="$(grep -m1 '^NET_WEI=' "$f" | cut -d= -f2-)"
        local stage="$(grep -m1 '^STAGE=' "$f" | cut -d= -f2-)"
        local status="$(grep -m1 '^STATUS=' "$f" | cut -d= -f2-)"
        printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
            "$cid" "$created" "$buyer" "$seller" "$amount" \
            "$la" "$lb" "$cf" "$net" "$stage" "$status" >> "$file"
    done
    echo "OK: $file"
    echo "Rows: $(wc -l < "$file")"
}

exp_ledger_csv() {
    local file="$OUT/ledger_$(date -u +%Y%m%d).csv"
    echo "TIMESTAMP,CONTRACT,TYPE,AMOUNT,LICENSE,RECIPIENT" > "$file"
    local base="$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence"
    cat "$base/license_ledger.txt" 2>/dev/null | \
        awk -F'|' '{gsub(/^ +| +$/,"",$1);gsub(/^ +| +$/,"",$2);gsub(/^ +| +$/,"",$3);gsub(/^ +| +$/,"",$4);gsub(/^ +| +$/,"",$5);gsub(/^ +| +$/,"",$6); print $1","$2",A,"$4","$5","$6}' >> "$file"
    cat "$base/license_ledger_b.txt" 2>/dev/null | \
        awk -F'|' '{gsub(/^ +| +$/,"",$1);gsub(/^ +| +$/,"",$2);gsub(/^ +| +$/,"",$3);gsub(/^ +| +$/,"",$4);gsub(/^ +| +$/,"",$5);gsub(/^ +| +$/,"",$6); print $1","$2",B,"$4","$5","$6}' >> "$file"
    echo "OK: $file"
}

exp_txt_report() {
    local cid="$1" file="$OUT/${cid}.txt"
    local f="$HOME/CYBRA/modules/module_19_contract_tui_menu/contracts/$cid.env"
    [ -f "$f" ] || { echo "ERR: not found"; return 1; }
    {
        echo "═══ CYBRA CONTRACT REPORT ═══"
        echo ""
        echo "ID:        $cid"
        echo "Generated: $(date -u +%FT%TZ)"
        echo ""
        echo "--- DATA ---"
        grep -E '^(BUYER|SELLER|AMOUNT_WEI|TOKEN|LICENSE_A_WEI|LICENSE_B_WEI|CREATION_FEE_WEI|NET_WEI|STAGE|STATUS)=' "$f" | sed 's/^/  /'
        echo ""
        echo "--- LEDGER ---"
        grep "$cid" "$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence/license_ledger.txt" 2>/dev/null | sed 's/^/  /'
        grep "$cid" "$HOME/CYBRA/modules/module_19_contract_tui_menu/evidence/license_ledger_b.txt" 2>/dev/null | sed 's/^/  /'
    } > "$file"
    echo "OK: $file"
}

exp_pdf_from_txt() {
    local txt="$1"
    [ -f "$txt" ] || { echo "ERR: no txt"; return 1; }
    if command -v enscript >/dev/null 2>&1 && command -v ps2pdf >/dev/null 2>&1; then
        enscript -p - "$txt" 2>/dev/null | ps2pdf - "${txt%.txt}.pdf"
        echo "OK: ${txt%.txt}.pdf"
    else
        echo "WARN: enscript/ghostscript missing"
        echo "Try: pkg install enscript ghostscript"
        echo "TXT kept at: $txt"
    fi
}

exp_all() {
    exp_contracts_csv
    exp_ledger_csv
    echo ""
    echo "--- OUTPUT ---"
    ls -lh "$OUT" | tail -10
}
