#!/data/data/com.termux/files/usr/bin/bash
# CYBRA CONTRACT TUI v1.1 — повний
source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh" 2>/dev/null || true
source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_health.sh" 2>/dev/null || true

# ─── Кольори ───
if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'; C_MAGENTA=$'\033[35m'
    C_GREY=$'\033[90m'
else
    C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""
    C_YELLOW=""; C_BLUE=""; C_CYAN=""; C_MAGENTA=""; C_GREY=""
fi

CYBRA_ICON() {
    case "$1" in
        OK)   printf '🟢' ;;
        WARN) printf '🟡' ;;
        ERR)  printf '🔴' ;;
        *)    printf '⚪' ;;
    esac
}

# ─── Actions: ОСНОВНЕ ───
action_create_contract() {
    printf '%s\n' "${C_BOLD}--- Створити контракт ---${C_RESET}"
    printf 'BUYER (0x...):  '; read -r B
    printf 'SELLER (0x...): '; read -r S
    printf 'AMOUNT (wei):   '; read -r A
    printf 'TOKEN [BNB]:    '; read -r T; T="${T:-BNB}"
    [ -z "$B" ] || [ -z "$S" ] || [ -z "$A" ] && { printf '%s\n' "${C_RED}Помилка${C_RESET}"; read -r _; return 1; }
    CID="$(cybra_contract_create "$B" "$S" "$A" "$T")"
    printf '%s\n' "${C_GREEN}OK: $CID${C_RESET}"
    printf 'CONTRACT_ID: %s\n' "$CID"
    read -r _
}

action_list_contracts() {
    printf '%s\n' "${C_BOLD}--- Контракти ---${C_RESET}"
    local n=0
    for f in "$CYBRA_CONTRACTS"/*.env; do
        [ -f "$f" ] || continue
        local cid="$(basename "$f" .env)"
        local stage="$(grep -m1 '^STAGE=' "$f" | cut -d= -f2-)"
        printf '  %-45s [%s]\n' "$cid" "$stage"
        n=$((n+1))
    done
    printf '\nВсього: %s\n' "$n"
    read -r _
}

action_show_status() {
    printf 'CONTRACT_ID: '; read -r C
    local f="$CYBRA_CONTRACTS/$C.env"
    [ ! -f "$f" ] && { printf '%s\n' "${C_RED}Not found${C_RESET}"; read -r _; return 1; }
    cat "$f" | sed 's/^/  /'
    read -r _
}

action_generate_links() {
    printf 'CONTRACT_ID: '; read -r C
    for r in BUYER SELLER RECEIPT; do
        L="$(cybra_link_generate "$C" "$r")"
        printf '  %s -> %s\n' "$r" "$L"
    done
    read -r _
}

action_confirm_link() {
    printf 'LINK_ID: '; read -r L
    printf 'WHO:     '; read -r W
    cybra_link_confirm "$L" "$W"
    read -r _
}

action_debug() {
    printf 'CONTRACT_ID: '; read -r C
    cat "$CYBRA_CONTRACTS/$C.env" 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "--- links ---"
    for lf in "$CYBRA_LINKS"/*.link; do
        [ -f "$lf" ] || continue
        grep -q "CONTRACT_ID=$C" "$lf" && cat "$lf" | sed 's/^/  /'
    done
    read -r _
}

action_dual_license_ledger() {
    printf '%s\n' "${C_BOLD}--- DUAL LICENSE ledger (A+B) ---${C_RESET}"
    printf '\n--- A ---\n'
    tail -20 "$MOD/evidence/license_ledger.txt" 2>/dev/null
    printf '\n--- B ---\n'
    tail -20 "$MOD/evidence/license_ledger_b.txt" 2>/dev/null
    read -r _
}

action_creation_license() {
    printf '%s\n' "${C_BOLD}--- CREATION LICENSE ledger ---${C_RESET}"
    tail -20 "$MOD/evidence/creation_license_ledger.txt" 2>/dev/null
    read -r _
}

action_hardening() {
    printf '%s\n' "${C_BOLD}--- Hardening ---${C_RESET}"
    if [ -x "$HOME/CYBRA/cybra_mega_hardening.sh" ]; then
        "$HOME/CYBRA/cybra_mega_hardening.sh" 2>&1 | tail -30
    else
        printf '%s\n' "${C_RED}hardening not found${C_RESET}"
    fi
    read -r _
}

# ─── INVOICE ───
action_create_invoice() {
    printf '%s\n' "${C_BOLD}--- INVOICE ---${C_RESET}"
    printf 'ПІБ покупця:     '; read -r BN
    printf 'ІПН покупця:     '; read -r BI
    printf 'Wallet покупця:  '; read -r BW
    printf 'Продавець:       '; read -r SN
    printf 'ЄДРПОУ:          '; read -r SE
    printf 'Wallet продавця: '; read -r SW
    printf '№ рахунку:       '; read -r IN
    printf 'Дата:            '; read -r ID
    printf 'Сума (wei):      '; read -r AM
    printf 'Token:           '; read -r TK
    CID="$(cybra_contract_create_invoice "$BN" "$BI" "$BW" "$SN" "$SE" "$SW" "$IN" "$ID" "$AM" "$TK" 18 20)" 2>/dev/null
    [ -z "$CID" ] && { printf '%s\n' "${C_RED}Fail${C_RESET}"; read -r _; return 1; }
    printf '%s\n' "${C_GREEN}OK: $CID${C_RESET}"
    read -r _
}

action_add_line() {
    printf 'CONTRACT_ID: '; read -r C
    printf 'Код:        '; read -r CODE
    printf 'Назва:      '; read -r NAME
    printf 'К-сть:      '; read -r QTY
    printf 'Ціна:       '; read -r PRICE
    cybra_invoice_add_line "$C" "$CODE" "$NAME" "$QTY" "$PRICE" 2>/dev/null
    read -r _
}

action_show_invoice() {
    printf 'CONTRACT_ID: '; read -r C
    cybra_invoice_show "$C" 2>/dev/null
    read -r _
}

action_finalize_invoice() {
    printf 'CONTRACT_ID: '; read -r C
    cybra_invoice_finalize "$C" 2>/dev/null
    read -r _
}

# ─── PII MASK ───
action_export_masked() {
    printf 'CONTRACT_ID: '; read -r C
    local h="$(cybra_export_masked "$C" "$HOME/CYBRA/public/contracts" 2>/dev/null)"
    printf '%s\n' "${C_GREEN}Export: ${h:0:16}...${C_RESET}"
    read -r _
}
action_export_all_masked() {
    cybra_export_all_masked "$HOME/CYBRA/public/contracts" 2>/dev/null
    read -r _
}
action_verify_pii() {
    printf 'Значення: '; read -r V
    printf 'Hash:     '; read -r H
    local c="$(cybra_pii_hash "$V" 2>/dev/null)"
    [ "$c" = "$H" ] && printf '%s\n' "${C_GREEN}MATCH${C_RESET}" || printf '%s\n' "${C_RED}MISMATCH${C_RESET}"
    read -r _
}

# ─── REFUND ───
action_buyer_final_decision() {
    printf 'CONTRACT_ID: '; read -r C
    printf 'Рішення [CONFIRMED/REJECTED]: '; read -r D
    cybra_buyer_final_decision "$C" "$D" 2>/dev/null
    read -r _
}
action_check_timeouts() {
    cybra_check_all_refunds 2>/dev/null
    read -r _
}
action_refund_status() {
    printf 'CONTRACT_ID: '; read -r C
    cybra_refund_status "$C" 2>/dev/null
    read -r _
}
action_add_term() {
    printf 'CONTRACT_ID: '; read -r C
    printf 'Умова:       '; read -r T
    cybra_add_custom_term "$C" "$T" 2>/dev/null
    read -r _
}

# ─── ВАЛЮТИ ───
action_show_rates() {
    cybra_show_rates 2>/dev/null
    read -r _
}
action_update_rate() {
    printf 'RATE_KEY: '; read -r K
    printf 'VALUE:    '; read -r V
    local rf="$MOD/state/rates.env"
    if grep -q "^${K}=" "$rf" 2>/dev/null; then
        sed -i "s|^${K}=.*|${K}=${V}|" "$rf"
    else
        printf '%s=%s\n' "$K" "$V" >> "$rf"
    fi
    printf '%s\n' "${C_GREEN}OK${C_RESET}"
    read -r _
}
action_convert() {
    printf 'Сума:  '; read -r A
    printf 'З:     '; read -r F
    printf 'У:     '; read -r T
    printf '  Див. курси в [22]\n'
    read -r _
}

# ─── СИСТЕМА ───
action_preflight() {
    bash "$MOD/bin/cybra_preflight.sh" 2>/dev/null
    read -r _
}
action_self_heal() {
    bash "$MOD/bin/cybra_self_heal.sh" 2>/dev/null
    read -r _
}
action_dual_verify() {
    printf 'CONTRACT_ID: '; read -r C
    cybra_contract_compute_dual_hash "$C" >/dev/null 2>&1
    cybra_contract_verify_dual "$C" 2>/dev/null
    read -r _
}
action_ownership() {
    cybra_ownership_scan 2>/dev/null
    read -r _
}

# ─── AI ───
action_ai_review() {
    printf 'CONTRACT_ID: '; read -r C
    source "$MOD/bin/cybra_local_ai.sh" 2>/dev/null
    local_ai_review_contract "$C" 2>/dev/null || printf 'AI недоступний\n'
    read -r _
}
action_ai_parse() {
    source "$MOD/bin/cybra_local_ai.sh" 2>/dev/null
    local_ai_parse_invoice 2>/dev/null
    read -r _
}
action_ai_terms() {
    printf 'CONTRACT_ID: '; read -r C
    source "$MOD/bin/cybra_local_ai.sh" 2>/dev/null
    local_ai_generate_terms "$C" 2>/dev/null
    read -r _
}
action_ai_help() {
    printf 'Помилка: '; read -r E
    source "$MOD/bin/cybra_local_ai.sh" 2>/dev/null
    local_ai_help_error "$E" 2>/dev/null
    read -r _
}
action_ai_ask() {
    printf 'Питання: '; read -r Q
    source "$MOD/bin/cybra_local_ai.sh" 2>/dev/null
    local_ai_answer "$Q" 2>/dev/null
    read -r _
}
action_ai_taskbar() {
    if [ -x "$HOME/CYBRA/CYBRA_AI_TASK_BAR.sh" ]; then
        "$HOME/CYBRA/CYBRA_AI_TASK_BAR.sh"
    else
        printf '%s\n' "${C_RED}AI Task Bar не знайдено${C_RESET}"
        read -r _
    fi
}

# ─── AI EVOLUTION ───
action_ai_exec_full()  { "$HOME/CYBRA/ai/cybra_ai_executor.sh" full 2>&1 | tail -30; read -r _; }
action_ai_exec_scan()  { "$HOME/CYBRA/ai/cybra_ai_executor.sh" scan 2>&1 | tail -30; read -r _; }
action_ai_exec_apply() { "$HOME/CYBRA/ai/cybra_ai_executor.sh" apply 2>&1 | tail -30; read -r _; }
action_ai_exec_list()  { ls -la "$HOME/CYBRA/ai/evolution/suggestions/" 2>/dev/null; read -r _; }

# ─── ADDRESS BOOK ───
action_addr_add() {
    printf 'Name:    '; read -r N
    printf 'Address: '; read -r A
    printf 'Tag:     '; read -r T
    source "$HOME/CYBRA/modules/module_25_address_book/bin/address_book.sh" 2>/dev/null
    ab_add "$N" "$A" "${T:-user}" 2>/dev/null
    read -r _
}
action_addr_list()    { source "$HOME/CYBRA/modules/module_25_address_book/bin/address_book.sh" 2>/dev/null; ab_list 2>/dev/null; read -r _; }
action_addr_history() { source "$HOME/CYBRA/modules/module_25_address_book/bin/address_book.sh" 2>/dev/null; ab_history 2>/dev/null; read -r _; }

# ─── INTEGRATIONS ───
action_qr() {
    printf 'CONTRACT_ID: '; read -r C
    printf 'ROLE:        '; read -r R
    source "$HOME/CYBRA/modules/module_26_qr_codes/bin/qr.sh" 2>/dev/null
    qr_gen_link "$C" "${R:-BUYER}" 2>/dev/null
    read -r _
}
action_tg_setup() {
    printf 'Bot Token: '; read -r T
    printf 'Chat ID:   '; read -r C
    source "$HOME/CYBRA/modules/module_27_telegram_bot/bin/tg.sh" 2>/dev/null
    tg_set_token "$T"; tg_set_chat "$C"
    read -r _
}
action_tg_test() {
    source "$HOME/CYBRA/modules/module_27_telegram_bot/bin/tg.sh" 2>/dev/null
    tg_test 2>/dev/null
    read -r _
}
action_wh_list() { source "$HOME/CYBRA/modules/module_32_webhook/bin/webhook.sh" 2>/dev/null; wh_list 2>/dev/null; read -r _; }
action_wh_add() {
    printf 'Name:   '; read -r N
    printf 'URL:    '; read -r U
    printf 'Events: '; read -r E
    source "$HOME/CYBRA/modules/module_32_webhook/bin/webhook.sh" 2>/dev/null
    wh_add "$N" "$U" "${E:-*}" 2>/dev/null
    read -r _
}

# ─── EXPORT / BACKUP ───
action_exp_csv()    { source "$HOME/CYBRA/modules/module_28_export/bin/export.sh" 2>/dev/null; exp_contracts_csv 2>/dev/null; read -r _; }
action_exp_ledger() { source "$HOME/CYBRA/modules/module_28_export/bin/export.sh" 2>/dev/null; exp_ledger_csv 2>/dev/null; read -r _; }
action_exp_report() {
    printf 'CONTRACT_ID: '; read -r C
    source "$HOME/CYBRA/modules/module_28_export/bin/export.sh" 2>/dev/null
    exp_txt_report "$C" 2>/dev/null
    read -r _
}
action_bk_local() { source "$HOME/CYBRA/modules/module_29_backup/bin/backup.sh" 2>/dev/null; bk_local 2>/dev/null; read -r _; }
action_bk_cloud() { source "$HOME/CYBRA/modules/module_29_backup/bin/backup.sh" 2>/dev/null; bk_cloud 2>/dev/null; read -r _; }

# ─── MULTI-CHAIN ───
action_chains() {
    source "$HOME/CYBRA/modules/module_30_multichain/bin/multichain.sh" 2>/dev/null
    mc_list 2>/dev/null
    read -r _
}
action_scan_tx() {
    printf 'CHAIN [BSC]: '; read -r C
    printf 'TX:          '; read -r T
    source "$HOME/CYBRA/modules/module_30_multichain/bin/multichain.sh" 2>/dev/null
    mc_tx_link "${C:-BSC}" "$T" 2>/dev/null
    read -r _
}

# ─── DISPUTE / AUDIT ───
action_dp_open() {
    printf 'CONTRACT_ID: '; read -r C
    printf 'OPENED_BY:   '; read -r B
    printf 'REASON:      '; read -r R
    source "$HOME/CYBRA/modules/module_31_dispute_resolver/bin/dispute.sh" 2>/dev/null
    dp_open "$C" "$B" "$R" 2>/dev/null
    read -r _
}
action_dp_list() { source "$HOME/CYBRA/modules/module_31_dispute_resolver/bin/dispute.sh" 2>/dev/null; dp_list 2>/dev/null; read -r _; }
action_dp_vote() {
    printf 'DISPUTE_ID: '; read -r D
    printf 'VOTER:      '; read -r V
    printf 'VOTE:       '; read -r O
    source "$HOME/CYBRA/modules/module_31_dispute_resolver/bin/dispute.sh" 2>/dev/null
    dp_vote "$D" "$V" "$O" 2>/dev/null
    read -r _
}
action_audit_show()   { source "$HOME/CYBRA/modules/module_33_audit_log/bin/audit.sh" 2>/dev/null; au_show 2>/dev/null; read -r _; }
action_audit_verify() { source "$HOME/CYBRA/modules/module_33_audit_log/bin/audit.sh" 2>/dev/null; au_verify 2>/dev/null; read -r _; }

# ─── DOCUMENT SCANNER ───
action_scan_photo() { source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh" 2>/dev/null; sc_photo 2>/dev/null; read -r _; }
action_scan_ocr()   { printf 'File: '; read -r F; source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh" 2>/dev/null; sc_ocr "$F" 2>/dev/null; read -r _; }
action_scan_pdf()   { printf 'PDF:  '; read -r F; source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh" 2>/dev/null; sc_pdf_to_text "$F" 2>/dev/null; read -r _; }
action_scan_full()  { source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh" 2>/dev/null; sc_scan_pipeline 2>/dev/null; read -r _; }

# ─── GUARDIAN ───
GD_LIB="$HOME/CYBRA/modules/module_35_cybra_guardian/bin/guardian.sh"

action_gd_state()        { source "$GD_LIB" 2>/dev/null; gd_check_state 2>/dev/null; read -r _; }
action_gd_100()          {
    source "$GD_LIB" 2>/dev/null
    gd_check_state >/dev/null 2>&1
    local p="$(cat "$GUARD_EV/state_pct.txt" 2>/dev/null || echo 0)"
    if [ "$p" -eq 100 ]; then
        printf '%s✓ 100%% STATE%s\n' "${C_GREEN}" "${C_RESET}"
    else
        printf '%s✗ %s%% — потрібно відновлення%s\n' "${C_RED}" "$p" "${C_RESET}"
    fi
    read -r _
}
action_gd_register() {
    source "$GD_LIB" 2>/dev/null
    printf "Ім'я:      "; read -r N
    printf "ID номер:  "; read -r I
    printf "Wallet:    "; read -r W
    printf "Bio [none]: "; read -r B
    gd_register "$N" "$I" "$W" "${B:-none}" 2>/dev/null
    read -r _
}
action_gd_show()         { source "$GD_LIB" 2>/dev/null; gd_show_identity 2>/dev/null; read -r _; }
action_gd_verify() {
    source "$GD_LIB" 2>/dev/null
    printf "Ім'я:      "; read -r N
    printf "ID номер:  "; read -r I
    printf "Wallet:    "; read -r W
    printf "Bio [none]: "; read -r B
    gd_verify "$N" "$I" "$W" "${B:-none}" 2>/dev/null
    read -r _
}
action_gd_device()       { source "$GD_LIB" 2>/dev/null; gd_device_info 2>/dev/null; read -r _; }
action_gd_snapshot()     { source "$GD_LIB" 2>/dev/null; gd_recovery_snapshot 2>/dev/null; read -r _; }
action_gd_restore_git()  { source "$GD_LIB" 2>/dev/null; gd_recovery_from_git 2>/dev/null; read -r _; }
action_gd_restore_snap() { source "$GD_LIB" 2>/dev/null; gd_recovery_from_snapshot 2>/dev/null; read -r _; }
action_gd_auto()         { source "$GD_LIB" 2>/dev/null; gd_auto_recover 2>/dev/null; read -r _; }
action_gd_actions()      { tail -30 "$HOME/CYBRA/modules/module_35_cybra_guardian/evidence/actions.log" 2>/dev/null; read -r _; }
action_gd_log_verify()   { source "$GD_LIB" 2>/dev/null; gd_log_verify 2>/dev/null; read -r _; }

# ─── AUTOSAVE ───
AS_LIB="$HOME/CYBRA/modules/module_35_cybra_guardian/bin/autosave.sh"

action_as_save()      { source "$AS_LIB" 2>/dev/null; printf 'CONTRACT_ID: '; read -r C; as_save_all "$C" 2>/dev/null; read -r _; }
action_as_status()    { source "$AS_LIB" 2>/dev/null; as_status 2>/dev/null; read -r _; }
action_as_recent()    { source "$AS_LIB" 2>/dev/null; as_recent 2>/dev/null; read -r _; }
action_as_restore()   { source "$AS_LIB" 2>/dev/null; printf 'CONTRACT_ID: '; read -r C; as_restore_contract "$C" 2>/dev/null; read -r _; }
action_as_setup_email() {
    CONF="$HOME/CYBRA/modules/module_35_cybra_guardian/state/autosave.env"
    printf 'From:   '; read -r F
    printf 'To:     '; read -r T
    printf 'Host:   '; read -r H
    printf 'Port:   '; read -r P
    printf 'User:   '; read -r U
    printf 'Pass:   '; read -rs PW; echo
    sed -i "s|^EMAIL_FROM=.*|EMAIL_FROM=$F|"        "$CONF"
    sed -i "s|^EMAIL_TO=.*|EMAIL_TO=$T|"            "$CONF"
    sed -i "s|^EMAIL_SMTP_HOST=.*|EMAIL_SMTP_HOST=$H|" "$CONF"
    sed -i "s|^EMAIL_SMTP_PORT=.*|EMAIL_SMTP_PORT=$P|" "$CONF"
    sed -i "s|^EMAIL_SMTP_USER=.*|EMAIL_SMTP_USER=$U|" "$CONF"
    sed -i "s|^EMAIL_SMTP_PASS=.*|EMAIL_SMTP_PASS=$PW|" "$CONF"
    sed -i "s|^EMAIL_ENABLED=.*|EMAIL_ENABLED=TRUE|"   "$CONF"
    sed -i "s|^AUTOSAVE_EMAIL=.*|AUTOSAVE_EMAIL=TRUE|" "$CONF"
    printf '%s\n' "${C_GREEN}OK${C_RESET}"
    read -r _
}
action_as_setup_cloud() {
    CONF="$HOME/CYBRA/modules/module_35_cybra_guardian/state/autosave.env"
    printf 'Provider: '; read -r P
    printf 'Path:     '; read -r PA
    sed -i "s|^CLOUD_PROVIDER=.*|CLOUD_PROVIDER=$P|"   "$CONF"
    sed -i "s|^CLOUD_PATH=.*|CLOUD_PATH=$PA|"          "$CONF"
    sed -i "s|^CLOUD_ENABLED=.*|CLOUD_ENABLED=TRUE|"   "$CONF"
    sed -i "s|^AUTOSAVE_CLOUD=.*|AUTOSAVE_CLOUD=TRUE|" "$CONF"
    printf '%s\n' "${C_GREEN}OK${C_RESET}"
    read -r _
}

# ─── HEADER ───
print_header() {
    clear 2>/dev/null || printf '\033[2J\033[H'
    local mods=0
    for d in "$HOME/CYBRA/modules"/*/; do
        [ -d "$d" ] || continue
        local m=$(basename "$d")
        case "$m" in @*|.*|_disabled*|evolution|answer_engine|node_modules) continue;; esac
        mods=$((mods+1))
    done
    local cons=0
    for f in "$CYBRA_CONTRACTS"/*.env; do [ -f "$f" ] && cons=$((cons+1)); done
    local links=0
    for f in "$CYBRA_LINKS"/*.link; do [ -f "$f" ] && links=$((links+1)); done
    local now="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"

    printf '%s\n' "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════${C_RESET}"
    printf '%s\n' "${C_BOLD}${C_CYAN}              CYBRA CONTRACT MANAGER — TUI v1.1${C_RESET}"
    printf '%s\n' "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════${C_RESET}"
    printf '  🟢 READY  │  BSC(56)  │  1%%+1%%+1%% license\n'
    printf '  %s modules  │  %s contracts  │  %s links\n' "$mods" "$cons" "$links"
    printf '%s\n' "  ${C_GREY}🕐 $now${C_RESET}"
    printf '%s\n' "${C_GREY}────────────────────────────────────────────────────────────${C_RESET}"
    printf '\n'
}

# ─── MENU (усі секції) ───
print_menu() {
    printf '%s
' "${C_BOLD}  ─── ОСНОВНЕ ───${C_RESET}"
    printf '  🟢 %s[1]%s  Створити контракт
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[2]%s  Список контрактів
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[3]%s  Статус контракту
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[4]%s  Згенерувати лінки
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[5]%s  Підтвердити лінк
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[6]%s  Debug
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[7]%s  DUAL-LICENSE ledger
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[8]%s  CREATION-LICENSE ledger
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[9]%s  Hardening
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_CYAN}  ─── INVOICE ───${C_RESET}"
    printf '  🟢 %s[10]%s Підписати INVOICE (продавець)
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[11]%s Створити INVOICE
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[12]%s Додати позицію
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[13]%s Показати INVOICE
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[14]%s Фіналізувати INVOICE
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_CYAN}  ─── PII MASK ───${C_RESET}"
    printf '  🟢 %s[15]%s Експорт PII-masked
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[16]%s Експорт усіх + git
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[17]%s Перевірити PII хеш
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_CYAN}  ─── REFUND ───${C_RESET}"
    printf '  🟢 %s[18]%s Фінальне рішення покупця
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[19]%s Перевірити timeout
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[20]%s Статус refund
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[21]%s Додати умову
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_CYAN}  ─── ВАЛЮТИ ───${C_RESET}"
    printf '  🟢 %s[22]%s Показати курси
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[23]%s Оновити курс
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[24]%s Конвертер
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_CYAN}  ─── СИСТЕМА ───${C_RESET}"
    printf '  🟢 %s[30]%s Preflight
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[31]%s Self-heal
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[32]%s Dual-backend verify
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[33]%s Ownership scan
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_MAGENTA}  ─── AI (офлайн) ───${C_RESET}"
    printf '  🟢 %s[40]%s AI Аналіз
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[41]%s AI Парсинг рахунку
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[42]%s AI Генерація умов
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[43]%s AI Допомога
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[44]%s AI Вільне питання
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[45]%s AI Task Bar
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_MAGENTA}  ─── AI EVOLUTION ───${C_RESET}"
    printf '  🟢 %s[46]%s Executor — повний
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[47]%s Executor — scan
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[48]%s Executor — apply
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[49]%s Executor — список
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_GREEN}  ─── ADDRESS BOOK ───${C_RESET}"
    printf '  🟢 %s[50]%s Додати адресу
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[51]%s Список адрес
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[52]%s Історія адрес
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_GREEN}  ─── INTEGRATIONS ───${C_RESET}"
    printf '  🟢 %s[53]%s QR-код
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[54]%s Telegram — setup
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[55]%s Telegram — test
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[56]%s Webhook — список
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[57]%s Webhook — додати
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_GREEN}  ─── EXPORT / BACKUP ───${C_RESET}"
    printf '  🟢 %s[58]%s CSV — контракти
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[59]%s CSV — ledger
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[60]%s TXT — звіт
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[61]%s Backup — локальний
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[62]%s Backup — хмара
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_GREEN}  ─── MULTI-CHAIN ───${C_RESET}"
    printf '  🟢 %s[63]%s Список мереж
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[64]%s Сканер-tx
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_RED}  ─── DISPUTE / AUDIT ───${C_RESET}"
    printf '  🟢 %s[65]%s Відкрити спір
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[66]%s Список спорів
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[67]%s Голосувати
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[68]%s Audit log
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[69]%s Audit — перевірити
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_RED}  ─── DOCUMENT SCANNER ───${C_RESET}"
    printf '  🟢 %s[70]%s Сфотографувати
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[71]%s OCR
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[72]%s PDF → текст
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[73]%s Повний pipeline
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_MAGENTA}  ─── РОЗШИРЕНІ ───${C_RESET}"
    printf '  🟢 %s[74]%s Пошук контракту
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[75]%s Auto-fill контракту
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[76]%s AI прогін умов
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[77]%s Перевірка платежів
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[78]%s Додаткові умови
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[79]%s Watchdog (супервізор)
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_RED}  ─── GUARDIAN (100% state) ───${C_RESET}"
    printf '  🟢 %s[80]%s Стан системи
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[81]%s Перевірка 100%%
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[82]%s Зареєструвати особу
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[83]%s Показати особу
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[84]%s Перевірити особу
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[85]%s Пристрій
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[86]%s Snapshot
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[87]%s Відновити з git
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[88]%s Відновити з snapshot
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[89]%s AUTO-recovery
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[90]%s Action log
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[91]%s Log verify
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_RED}  ─── AUTOSAVE ───${C_RESET}"
    printf '  🟢 %s[92]%s Зберегти контракт
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[93]%s Статус autosave
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[94]%s Останні архіви
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[95]%s Відновити контракт
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_RED}  ─── EVO CONTROLLERS ───${C_RESET}"
    printf '  🟢 %s[96]%s EVO7 (7 рівнів)
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[97]%s EVO CONTROLLER (4 SHA)
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[98]%s Parawatch (фон)
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[99]%s AUTOPATCH
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "${C_MAGENTA}  ─── NODE / HASH / SYSTEM ───${C_RESET}"
    printf '  🟢 %s[100]%s Node manager
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[101]%s Hash ecosystem (5 layers)
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[102]%s Binmix daemon
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[103]%s Metrics (Prometheus)
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[104]%s HTTP panel
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[105]%s Schedule (cron)
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[106]%s Cleanup (ротація)
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[107]%s Autopilot (авто-оновлення)
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "  ${C_BOLD}─── NODE/HASH ───${C_RESET}"
    printf '  🟢 %s[121]%s parlament
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[120]%s ai guardian
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[119]%s qr sign
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[118]%s net health
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[117]%s tx lookup
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[116]%s gas monitor
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[115]%s rpc bench
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[114]%s autonode
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[113]%s metamask batch
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[112]%s metamask deeplink
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[111]%s metamask settings
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[110]%s metamask history
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[109]%s metamask verify
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[108]%s metamask sign
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "  ${C_BOLD}─── METAMASK ───${C_RESET}"
    printf '  🟢 %s[124]%s timelock
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[123]%s multisig
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[122]%s contract validator
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "  ${C_BOLD}─── ADVANCED ───${C_RESET}"
    printf '  🟢 %s[140]%s analytics
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[139]%s reputation
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[138]%s arbitration
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[137]%s escrow
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[136]%s templates
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[135]%s walletconnect
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[134]%s discord
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[133]%s tokens
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[132]%s compliance
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[131]%s kyc
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[130]%s test suite
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[129]%s voice
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[128]%s dashboard
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[126]%s zk
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[125]%s anchor
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "  ${C_BOLD}─── ORCHESTRATOR ───${C_RESET}"
    printf '  🟢 %s[150]%s Custom Scripts
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[149]%s Advanced Analytics
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[148]%s Multisig UI
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[147]%s On-chain Reputation v2
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[146]%s Merkle Batching
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[145]%s IPFS Pinning
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[144]%s Bitcoin Lightning
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[143]%s Email Notifications
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[142]%s Invoice PDF Export
' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[141]%s Portfolio Tracker
' "$C_BOLD" "$C_RESET"
    printf '
'

    printf '%s
' "  ${C_GREY}🟢 ready  🟡 warning  🔴 error${C_RESET}"
    printf '
'
    printf '  %s[0]%s  Вихід

' "$C_BOLD" "$C_RESET"
}

# ─── Main loop ───

action_evo7() {
    "$HOME/CYBRA/bin/cybra_evo7" menu
}


action_evo_ctl() {
    "$HOME/CYBRA/bin/cybra_evo_ctl" run
    read -r _
}

action_parawatch() {
    printf '  [1] Status\n'
    printf '  [2] Start (фон)\n'
    printf '  [3] Stop\n'
    printf '  [4] Once\n'
    printf 'Вибір: '
    read -r pw
    case "$pw" in
        1) "$HOME/CYBRA/bin/cybra_parawatch" status; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_parawatch" start; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_parawatch" stop; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_parawatch" once; read -r _ ;;
    esac
}

action_autopatch_menu() {
    printf '  [1] Dry-run\n'
    printf '  [2] Патчити все\n'
    printf '  [3] Тільки контракти\n'
    printf 'Вибір: '
    read -r ap
    case "$ap" in
        1) "$HOME/CYBRA/bin/cybra_autopatch" check; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_autopatch" all; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_autopatch" contracts; read -r _ ;;
    esac
}


action_watchdog() {
    printf '  [1] Status\n'
    printf '  [2] Start (фон)\n'
    printf '  [3] Stop\n'
    printf '  [4] Once\n'
    printf 'Вибір: '
    read -r wd
    case "$wd" in
        1) "$HOME/CYBRA/bin/cybra_watchdog" status; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_watchdog" start; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_watchdog" stop; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_watchdog" once; read -r _ ;;
    esac
}


action_boot() {
    "$HOME/CYBRA/bin/cybra_boot"
    read -r _
}


action_web() {
    printf '  [1] Status\n'
    printf '  [2] Start (фон)\n'
    printf '  [3] Stop\n'
    printf '  [4] Restart\n'
    printf 'Вибір: '
    read -r w
    case "$w" in
        1) "$HOME/CYBRA/bin/cybra_web" status; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_web" start; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_web" stop; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_web" restart; read -r _ ;;
    esac
}

action_export() {
    printf 'Файл [~/cybra_export.tar.gz]: '
    read -r OUT
    [ -z "$OUT" ] && OUT="$HOME/cybra_export.tar.gz"
    "$HOME/CYBRA/bin/cybra_export" "$OUT"
    read -r _
}

action_import() {
    printf 'Файл архіву: '
    read -r IN
    [ -z "$IN" ] && return
    "$HOME/CYBRA/bin/cybra_import" "$IN"
    read -r _
}



# ═══ SYSTEM (76-79) ═══
action_metrics() {
    "$HOME/CYBRA/bin/cybra_metrics" -v 2>&1 | head -40
    read -r _
}

action_http() {
    printf '  [1] Status\n'
    printf '  [2] Start (фон)\n'
    printf '  [3] Stop\n'
    printf '  [4] Test\n'
    printf 'Вибір: '
    read -r h
    case "$h" in
        1) "$HOME/CYBRA/bin/cybra_http" status 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_http" start 2>&1; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_http" stop 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_http" test 2>&1; read -r _ ;;
    esac
}

action_schedule() {
    printf '  [1] Status\n'
    printf '  [2] Start\n'
    printf '  [3] Stop\n'
    printf '  [4] List rules\n'
    printf 'Вибір: '
    read -r sc
    case "$sc" in
        1) "$HOME/CYBRA/bin/cybra_schedule" status 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_schedule" start 2>&1; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_schedule" stop 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_schedule" list 2>&1; read -r _ ;;
    esac
}

action_cleanup() {
    "$HOME/CYBRA/bin/cybra_cleanup" 2>&1
    read -r _
}

action_binmix() {
    printf '  [1] Status\n'
    printf '  [2] Start\n'
    printf '  [3] Stop\n'
    printf '  [4] Snapshot\n'
    printf '  [5] Chain\n'
    printf '  [6] Log\n'
    printf 'Вибір: '
    read -r bm
    case "$bm" in
        1) "$HOME/CYBRA/bin/cybra_binmix" status 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_binmix" start 2>&1; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_binmix" stop 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_binmix" snapshot 2>&1; read -r _ ;;
        5) "$HOME/CYBRA/bin/cybra_binmix" chain 2>&1; read -r _ ;;
        6) "$HOME/CYBRA/bin/cybra_binmix" log 2>&1 | tail -15; read -r _ ;;
    esac
}

action_hash_eco() {
    printf '  [1] Run (5 layers)\n'
    printf '  [2] List snapshots\n'
    printf '  [3] Push\n'
    printf '  [4] Cleanup\n'
    printf 'Вибір: '
    read -r he
    case "$he" in
        1) "$HOME/CYBRA/cybra_hash.sh" layers 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/cybra_hash.sh" list 2>&1 | head -20; read -r _ ;;
        3) "$HOME/CYBRA/cybra_hash.sh" push 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/cybra_hash.sh" cleanup 2>&1; read -r _ ;;
    esac
}

action_node() {
    printf '  [1] Check\n'
    printf '  [2] Fix\n'
    printf '  [3] Test\n'
    printf '  [4] Sync\n'
    printf '  [5] Push\n'
    printf '  [6] Run all\n'
    printf 'Вибір: '
    read -r nd
    case "$nd" in
        1) "$HOME/CYBRA/cybra_node.sh" check 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/cybra_node.sh" fix 2>&1; read -r _ ;;
        3) "$HOME/CYBRA/cybra_node.sh" test 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/cybra_node.sh" sync 2>&1; read -r _ ;;
        5) "$HOME/CYBRA/cybra_node.sh" push 2>&1; read -r _ ;;
        6) "$HOME/CYBRA/cybra_node.sh" run 2>&1; read -r _ ;;
    esac
}


action_autopilot() {
    printf '  [1] Status\n'
    printf '  [2] Start (фон)\n'
    printf '  [3] Stop\n'
    printf '  [4] One cycle\n'
    printf '  [5] Log\n'
    printf 'Вибір: '
    read -r ap
    case "$ap" in
        1) "$HOME/CYBRA/bin/cybra_autopilot" status 2>&1; read -r _ ;;
        2) "$HOME/CYBRA/bin/cybra_autopilot" start 2>&1; read -r _ ;;
        3) "$HOME/CYBRA/bin/cybra_autopilot" stop 2>&1; read -r _ ;;
        4) "$HOME/CYBRA/bin/cybra_autopilot" once 2>&1; read -r _ ;;
        5) tail -30 "$HOME/CYBRA/logs/autopilot.log" 2>/dev/null; read -r _ ;;
    esac
}



# ─── GENERIC ACTIONS (заглушки) ───
action_generic_10() {
    echo "Пункт [10] в розробці"
    read -r _
}
action_generic_25() {
    echo "Пункт [25] в розробці"
    read -r _
}
action_generic_26() {
    echo "Пункт [26] в розробці"
    read -r _
}
action_generic_27() {
    echo "Пункт [27] в розробці"
    read -r _
}
action_generic_28() {
    echo "Пункт [28] в розробці"
    read -r _
}
action_generic_29() {
    echo "Пункт [29] в розробці"
    read -r _
}
action_generic_34() {
    echo "Пункт [34] в розробці"
    read -r _
}
action_generic_35() {
    echo "Пункт [35] в розробці"
    read -r _
}
action_generic_36() {
    echo "Пункт [36] в розробці"
    read -r _
}
action_generic_37() {
    echo "Пункт [37] в розробці"
    read -r _
}
action_generic_38() {
    echo "Пункт [38] в розробці"
    read -r _
}
action_generic_39() {
    echo "Пункт [39] в розробці"
    read -r _
}
action_generic_40() {
    echo "Пункт [40] в розробці"
    read -r _
}
action_generic_41() {
    echo "Пункт [41] в розробці"
    read -r _
}
action_generic_42() {
    echo "Пункт [42] в розробці"
    read -r _
}
action_generic_43() {
    echo "Пункт [43] в розробці"
    read -r _
}
action_generic_44() {
    echo "Пункт [44] в розробці"
    read -r _
}
action_generic_45() {
    echo "Пункт [45] в розробці"
    read -r _
}
action_generic_46() {
    echo "Пункт [46] в розробці"
    read -r _
}
action_generic_47() {
    echo "Пункт [47] в розробці"
    read -r _
}
action_generic_48() {
    echo "Пункт [48] в розробці"
    read -r _
}
action_generic_49() {
    echo "Пункт [49] в розробці"
    read -r _
}
action_generic_50() {
    echo "Пункт [50] в розробці"
    read -r _
}
action_generic_51() {
    echo "Пункт [51] в розробці"
    read -r _
}
action_generic_52() {
    echo "Пункт [52] в розробці"
    read -r _
}
action_generic_53() {
    echo "Пункт [53] в розробці"
    read -r _
}
action_generic_54() {
    echo "Пункт [54] в розробці"
    read -r _
}
action_generic_55() {
    echo "Пункт [55] в розробці"
    read -r _
}
action_generic_56() {
    echo "Пункт [56] в розробці"
    read -r _
}
action_generic_57() {
    echo "Пункт [57] в розробці"
    read -r _
}
action_generic_58() {
    echo "Пункт [58] в розробці"
    read -r _
}
action_generic_59() {
    echo "Пункт [59] в розробці"
    read -r _
}
action_generic_60() {
    echo "Пункт [60] в розробці"
    read -r _
}
action_generic_61() {
    echo "Пункт [61] в розробці"
    read -r _
}
action_generic_62() {
    echo "Пункт [62] в розробці"
    read -r _
}
action_generic_63() {
    echo "Пункт [63] в розробці"
    read -r _
}
action_generic_64() {
    echo "Пункт [64] в розробці"
    read -r _
}
action_generic_65() {
    echo "Пункт [65] в розробці"
    read -r _
}
action_generic_66() {
    echo "Пункт [66] в розробці"
    read -r _
}
action_generic_67() {
    echo "Пункт [67] в розробці"
    read -r _
}
action_generic_68() {
    echo "Пункт [68] в розробці"
    read -r _
}
action_generic_69() {
    echo "Пункт [69] в розробці"
    read -r _
}
action_generic_70() {
    echo "Пункт [70] в розробці"
    read -r _
}
action_generic_71() {
    echo "Пункт [71] в розробці"
    read -r _
}
action_generic_72() {
    echo "Пункт [72] в розробці"
    read -r _
}
action_generic_73() {
    echo "Пункт [73] в розробці"
    read -r _
}
action_generic_74() {
    echo "Пункт [74] в розробці"
    read -r _
}
action_generic_75() {
    echo "Пункт [75] в розробці"
    read -r _
}
action_generic_76() {
    echo "Пункт [76] в розробці"
    read -r _
}
action_generic_77() {
    echo "Пункт [77] в розробці"
    read -r _
}
action_generic_78() {
    echo "Пункт [78] в розробці"
    read -r _
}
action_generic_79() {
    echo "Пункт [79] в розробці"
    read -r _
}
action_generic_80() {
    echo "Пункт [80] в розробці"
    read -r _
}
action_generic_81() {
    echo "Пункт [81] в розробці"
    read -r _
}
action_generic_82() {
    echo "Пункт [82] в розробці"
    read -r _
}
action_generic_83() {
    echo "Пункт [83] в розробці"
    read -r _
}
action_generic_84() {
    echo "Пункт [84] в розробці"
    read -r _
}
action_generic_85() {
    echo "Пункт [85] в розробці"
    read -r _
}
action_generic_86() {
    echo "Пункт [86] в розробці"
    read -r _
}
action_generic_87() {
    echo "Пункт [87] в розробці"
    read -r _
}
action_generic_88() {
    echo "Пункт [88] в розробці"
    read -r _
}
action_generic_89() {
    echo "Пункт [89] в розробці"
    read -r _
}
action_generic_90() {
    echo "Пункт [90] в розробці"
    read -r _
}
action_generic_91() {
    echo "Пункт [91] в розробці"
    read -r _
}
action_generic_92() {
    echo "Пункт [92] в розробці"
    read -r _
}
action_generic_93() {
    echo "Пункт [93] в розробці"
    read -r _
}
action_generic_94() {
    echo "Пункт [94] в розробці"
    read -r _
}
action_generic_95() {
    echo "Пункт [95] в розробці"
    read -r _
}
action_generic_96() {
    echo "Пункт [96] в розробці"
    read -r _
}
action_generic_97() {
    echo "Пункт [97] в розробці"
    read -r _
}
action_generic_98() {
    echo "Пункт [98] в розробці"
    read -r _
}
action_generic_99() {
    echo "Пункт [99] в розробці"
    read -r _
}
action_generic_100() {
    echo "Пункт [100] в розробці"
    read -r _
}
action_generic_101() {
    echo "Пункт [101] в розробці"
    read -r _
}
action_generic_102() {
    echo "Пункт [102] в розробці"
    read -r _
}
action_generic_103() {
    echo "Пункт [103] в розробці"
    read -r _
}
action_generic_104() {
    echo "Пункт [104] в розробці"
    read -r _
}
action_generic_105() {
    echo "Пункт [105] в розробці"
    read -r _
}
action_generic_106() {
    echo "Пункт [106] в розробці"
    read -r _
}
action_generic_107() {
    echo "Пункт [107] в розробці"
    read -r _
}
action_generic_108() {
    echo "Пункт [108] в розробці"
    read -r _
}
action_generic_109() {
    echo "Пункт [109] в розробці"
    read -r _
}
action_generic_110() {
    echo "Пункт [110] в розробці"
    read -r _
}
action_generic_111() {
    echo "Пункт [111] в розробці"
    read -r _
}
action_generic_112() {
    echo "Пункт [112] в розробці"
    read -r _
}
action_generic_113() {
    echo "Пункт [113] в розробці"
    read -r _
}
action_generic_114() {
    echo "Пункт [114] в розробці"
    read -r _
}
action_generic_115() {
    echo "Пункт [115] в розробці"
    read -r _
}
action_generic_116() {
    echo "Пункт [116] в розробці"
    read -r _
}
action_generic_117() {
    echo "Пункт [117] в розробці"
    read -r _
}
action_generic_118() {
    echo "Пункт [118] в розробці"
    read -r _
}
action_generic_119() {
    echo "Пункт [119] в розробці"
    read -r _
}
action_generic_120() {
    echo "Пункт [120] в розробці"
    read -r _
}
action_generic_121() {
    echo "Пункт [121] в розробці"
    read -r _
}
action_generic_122() {
    echo "Пункт [122] в розробці"
    read -r _
}
action_generic_123() {
    echo "Пункт [123] в розробці"
    read -r _
}
action_generic_124() {
    echo "Пункт [124] в розробці"
    read -r _
}
action_generic_125() {
    echo "Пункт [125] в розробці"
    read -r _
}
action_generic_126() {
    echo "Пункт [126] в розробці"
    read -r _
}
action_generic_127() {
    echo "Пункт [127] в розробці"
    read -r _
}
action_generic_128() {
    echo "Пункт [128] в розробці"
    read -r _
}
action_generic_129() {
    echo "Пункт [129] в розробці"
    read -r _
}
action_generic_130() {
    echo "Пункт [130] в розробці"
    read -r _
}
action_generic_131() {
    echo "Пункт [131] в розробці"
    read -r _
}
action_generic_132() {
    echo "Пункт [132] в розробці"
    read -r _
}
action_generic_133() {
    echo "Пункт [133] в розробці"
    read -r _
}
action_generic_134() {
    echo "Пункт [134] в розробці"
    read -r _
}
action_generic_135() {
    echo "Пункт [135] в розробці"
    read -r _
}
action_generic_136() {
    echo "Пункт [136] в розробці"
    read -r _
}
action_generic_137() {
    echo "Пункт [137] в розробці"
    read -r _
}
action_generic_138() {
    echo "Пункт [138] в розробці"
    read -r _
}
action_generic_139() {
    echo "Пункт [139] в розробці"
    read -r _
}
action_generic_140() {
    echo "Пункт [140] в розробці"
    read -r _
}
action_generic_141() {
    echo "Пункт [141] в розробці"
    read -r _
}
action_generic_142() {
    echo "Пункт [142] в розробці"
    read -r _
}
action_generic_143() {
    echo "Пункт [143] в розробці"
    read -r _
}
action_generic_144() {
    echo "Пункт [144] в розробці"
    read -r _
}
action_generic_145() {
    echo "Пункт [145] в розробці"
    read -r _
}
action_generic_146() {
    echo "Пункт [146] в розробці"
    read -r _
}
action_generic_147() {
    echo "Пункт [147] в розробці"
    read -r _
}
action_generic_148() {
    echo "Пункт [148] в розробці"
    read -r _
}
action_generic_149() {
    echo "Пункт [149] в розробці"
    read -r _
}
action_generic_150() {
    echo "Пункт [150] в розробці"
    read -r _
}

while true; do
    print_header
    print_menu
    printf '  Вибір: '
    read -r CHOICE

    case "$CHOICE" in
        1) action_create_contract ;;
        2) action_list_contracts ;;
        3) action_show_status ;;
        4) action_generate_links ;;
        5) action_confirm_link ;;
        6) action_debug ;;
        7) action_dual_license_ledger ;;
        8) action_creation_license ;;
        9) action_hardening ;;
        11) action_create_invoice ;;
        12) action_add_line ;;
        13) action_show_invoice ;;
        14) action_finalize_invoice ;;
        15) action_export_masked ;;
        16) action_export_all_masked ;;
        17) action_verify_pii ;;
        18) action_buyer_final_decision ;;
        19) action_check_timeouts ;;
        20) action_refund_status ;;
        21) action_add_term ;;
        22) action_show_rates ;;
        23) action_update_rate ;;
        24) action_convert ;;
        30) action_preflight ;;
        31) action_self_heal ;;
        32) action_dual_verify ;;
        33) action_ownership ;;
        0|q|Q|exit|quit)
            printf "%s
" "${C_GREEN}До побачення.${C_RESET}"
            exit 0
            ;;
        10) bash "$HOME/CYBRA/modules/module_10_generated/main.sh" ;;
        25) bash "$HOME/CYBRA/modules/module_25_generated/main.sh" ;;
        26) bash "$HOME/CYBRA/modules/module_26_generated/main.sh" ;;
        27) bash "$HOME/CYBRA/modules/module_27_generated/main.sh" ;;
        28) bash "$HOME/CYBRA/modules/module_28_generated/main.sh" ;;
        29) bash "$HOME/CYBRA/modules/module_29_generated/main.sh" ;;
        34) bash "$HOME/CYBRA/modules/module_34_generated/main.sh" ;;
        35) bash "$HOME/CYBRA/modules/module_35_generated/main.sh" ;;
        36) bash "$HOME/CYBRA/modules/module_36_generated/main.sh" ;;
        37) bash "$HOME/CYBRA/modules/module_37_generated/main.sh" ;;
        38) bash "$HOME/CYBRA/modules/module_38_generated/main.sh" ;;
        39) bash "$HOME/CYBRA/modules/module_39_generated/main.sh" ;;
        40) bash "$HOME/CYBRA/modules/module_40_generated/main.sh" ;;
        41) bash "$HOME/CYBRA/modules/module_41_generated/main.sh" ;;
        42) bash "$HOME/CYBRA/modules/module_42_generated/main.sh" ;;
        43) bash "$HOME/CYBRA/modules/module_43_generated/main.sh" ;;
        44) bash "$HOME/CYBRA/modules/module_44_generated/main.sh" ;;
        45) bash "$HOME/CYBRA/modules/module_45_generated/main.sh" ;;
        46) bash "$HOME/CYBRA/modules/module_46_generated/main.sh" ;;
        47) bash "$HOME/CYBRA/modules/module_47_generated/main.sh" ;;
        48) bash "$HOME/CYBRA/modules/module_48_generated/main.sh" ;;
        49) bash "$HOME/CYBRA/modules/module_49_generated/main.sh" ;;
        50) bash "$HOME/CYBRA/modules/module_50_generated/main.sh" ;;
        51) bash "$HOME/CYBRA/modules/module_51_generated/main.sh" ;;
        52) bash "$HOME/CYBRA/modules/module_52_generated/main.sh" ;;
        53) bash "$HOME/CYBRA/modules/module_53_generated/main.sh" ;;
        54) bash "$HOME/CYBRA/modules/module_54_generated/main.sh" ;;
        55) bash "$HOME/CYBRA/modules/module_55_generated/main.sh" ;;
        56) bash "$HOME/CYBRA/modules/module_56_generated/main.sh" ;;
        57) bash "$HOME/CYBRA/modules/module_57_generated/main.sh" ;;
        58) bash "$HOME/CYBRA/modules/module_58_generated/main.sh" ;;
        59) bash "$HOME/CYBRA/modules/module_59_generated/main.sh" ;;
        60) bash "$HOME/CYBRA/modules/module_60_generated/main.sh" ;;
        61) bash "$HOME/CYBRA/modules/module_61_generated/main.sh" ;;
        62) bash "$HOME/CYBRA/modules/module_62_generated/main.sh" ;;
        63) bash "$HOME/CYBRA/modules/module_63_generated/main.sh" ;;
        64) bash "$HOME/CYBRA/modules/module_64_generated/main.sh" ;;
        65) bash "$HOME/CYBRA/modules/module_65_generated/main.sh" ;;
        66) bash "$HOME/CYBRA/modules/module_66_generated/main.sh" ;;
        67) bash "$HOME/CYBRA/modules/module_67_generated/main.sh" ;;
        68) bash "$HOME/CYBRA/modules/module_68_generated/main.sh" ;;
        69) bash "$HOME/CYBRA/modules/module_69_generated/main.sh" ;;
        70) bash "$HOME/CYBRA/modules/module_70_generated/main.sh" ;;
        71) bash "$HOME/CYBRA/modules/module_71_generated/main.sh" ;;
        72) bash "$HOME/CYBRA/modules/module_72_generated/main.sh" ;;
        73) bash "$HOME/CYBRA/modules/module_73_generated/main.sh" ;;
        74) bash "$HOME/CYBRA/modules/module_74_generated/main.sh" ;;
        75) bash "$HOME/CYBRA/modules/module_75_generated/main.sh" ;;
        76) bash "$HOME/CYBRA/modules/module_76_generated/main.sh" ;;
        77) bash "$HOME/CYBRA/modules/module_77_generated/main.sh" ;;
        78) bash "$HOME/CYBRA/modules/module_78_generated/main.sh" ;;
        79) bash "$HOME/CYBRA/modules/module_79_generated/main.sh" ;;
        80) bash "$HOME/CYBRA/modules/module_80_generated/main.sh" ;;
        81) bash "$HOME/CYBRA/modules/module_81_generated/main.sh" ;;
        82) bash "$HOME/CYBRA/modules/module_82_generated/main.sh" ;;
        83) bash "$HOME/CYBRA/modules/module_83_generated/main.sh" ;;
        84) bash "$HOME/CYBRA/modules/module_84_generated/main.sh" ;;
        85) bash "$HOME/CYBRA/modules/module_85_generated/main.sh" ;;
        86) bash "$HOME/CYBRA/modules/module_86_generated/main.sh" ;;
        87) bash "$HOME/CYBRA/modules/module_87_generated/main.sh" ;;
        88) bash "$HOME/CYBRA/modules/module_88_generated/main.sh" ;;
        89) bash "$HOME/CYBRA/modules/module_89_generated/main.sh" ;;
        90) bash "$HOME/CYBRA/modules/module_90_generated/main.sh" ;;
        91) bash "$HOME/CYBRA/modules/module_91_generated/main.sh" ;;
        92) bash "$HOME/CYBRA/modules/module_92_generated/main.sh" ;;
        93) bash "$HOME/CYBRA/modules/module_93_generated/main.sh" ;;
        94) bash "$HOME/CYBRA/modules/module_94_generated/main.sh" ;;
        95) bash "$HOME/CYBRA/modules/module_95_generated/main.sh" ;;
        96) bash "$HOME/CYBRA/modules/module_96_generated/main.sh" ;;
        97) bash "$HOME/CYBRA/modules/module_97_generated/main.sh" ;;
        98) bash "$HOME/CYBRA/modules/module_98_generated/main.sh" ;;
        99) bash "$HOME/CYBRA/modules/module_99_generated/main.sh" ;;
        100) action_generic_100 ;;
        101) action_generic_101 ;;
        102) action_generic_102 ;;
        103) action_generic_103 ;;
        104) action_generic_104 ;;
        105) action_generic_105 ;;
        106) action_generic_106 ;;
        107) action_generic_107 ;;
        108) action_generic_108 ;;
        109) action_generic_109 ;;
        110) action_generic_110 ;;
        111) action_generic_111 ;;
        112) action_generic_112 ;;
        113) action_generic_113 ;;
        114) action_generic_114 ;;
        115) action_generic_115 ;;
        116) action_generic_116 ;;
        117) action_generic_117 ;;
        118) action_generic_118 ;;
        119) action_generic_119 ;;
        120) action_generic_120 ;;
        121) action_generic_121 ;;
        122) action_generic_122 ;;
        123) action_generic_123 ;;
        124) action_generic_124 ;;
        125) action_generic_125 ;;
        126) action_generic_126 ;;
        127) action_generic_127 ;;
        128) action_generic_128 ;;
        129) action_generic_129 ;;
        130) action_generic_130 ;;
        131) action_generic_131 ;;
        132) action_generic_132 ;;
        133) action_generic_133 ;;
        134) action_generic_134 ;;
        135) action_generic_135 ;;
        136) action_generic_136 ;;
        137) action_generic_137 ;;
        138) action_generic_138 ;;
        139) action_generic_139 ;;
        140) action_generic_140 ;;
        141) action_generic_141 ;;
        142) action_generic_142 ;;
        143) action_generic_143 ;;
        144) action_generic_144 ;;
        145) action_generic_145 ;;
        146) action_generic_146 ;;
        147) action_generic_147 ;;
        148) action_generic_148 ;;
        149) action_generic_149 ;;
        150) action_generic_150 ;;
        *)
            printf "%s
" "${C_RED}Невідома опція.${C_RESET}"
            ;;
    esac
done
