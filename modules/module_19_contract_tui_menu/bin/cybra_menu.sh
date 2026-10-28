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
    printf '%s\n' "  ${C_BOLD}[1]${C_RESET}  Створити контракт"
    printf '%s\n' "  ${C_BOLD}[2]${C_RESET}  Список контрактів"
    printf '%s\n' "  ${C_BOLD}[3]${C_RESET}  Статус контракту"
    printf '%s\n' "  ${C_BOLD}[4]${C_RESET}  Згенерувати лінки"
    printf '%s\n' "  ${C_BOLD}[5]${C_RESET}  Підтвердити лінк"
    printf '%s\n' "  ${C_BOLD}[6]${C_RESET}  Debug"
    printf '%s\n' "  ${C_BOLD}[7]${C_RESET}  DUAL-LICENSE ledger"
    printf '%s\n' "  ${C_BOLD}[8]${C_RESET}  CREATION-LICENSE ledger"
    printf '%s\n' "  ${C_BOLD}[9]${C_RESET}  Hardening"
    printf '%s\n' "${C_CYAN}  ── INVOICE ──${C_RESET}"
    printf '%s\n' "  ${C_BOLD}[11]${C_RESET} Створити INVOICE"
    printf '%s\n' "  ${C_BOLD}[12]${C_RESET} Додати позицію"
    printf '%s\n' "  ${C_BOLD}[13]${C_RESET} Показати INVOICE"
    printf '%s\n' "  ${C_BOLD}[14]${C_RESET} Фіналізувати INVOICE"
    printf '%s\n' "${C_CYAN}  ── REFUND ──${C_RESET}"
    printf '%s\n' "  ${C_BOLD}[18]${C_RESET} Фінальне рішення покупця"
    printf '%s\n' "  ${C_BOLD}[19]${C_RESET} Перевірити timeout"
    printf '%s\n' "  ${C_BOLD}[20]${C_RESET} Статус refund"
    printf '%s\n' "  ${C_BOLD}[21]${C_RESET} Додати умову"
    printf '%s\n' "${C_CYAN}  ── PII ──${C_RESET}"
    printf '%s\n' "  ${C_BOLD}[15]${C_RESET} Експорт PII-masked"
    printf '%s\n' "  ${C_BOLD}[16]${C_RESET} Експорт усіх + git"
    printf '%s\n' "  ${C_BOLD}[17]${C_RESET} Перевірити PII хеш"
    printf '%s\n' "${C_CYAN}  ── CURRENCY ──${C_RESET}"
    printf '%s\n' "  ${C_BOLD}[22]${C_RESET} Показати курси валют"
    printf '%s\n' "  ${C_BOLD}[23]${C_RESET} Оновити курс"
    printf '%s\n' "  ${C_BOLD}[24]${C_RESET} Конвертер валют"
    printf '%s\n' "${C_CYAN}  ── SYSTEM ──${C_RESET}"
    printf '%s\n' "  ${C_BOLD}[30]${C_RESET} Preflight (перевірка)"
    printf '%s\n' "  ${C_BOLD}[31]${C_RESET} Self-heal (автовідновлення)"
    printf '%s\n' "  ${C_BOLD}[32]${C_RESET} Dual-backend verify"
    printf '%s\n' "  ${C_BOLD}[33]${C_RESET} Ownership scan"
    echo ""
    echo "  ── 28..160: додано з модулів ──"
    printf "  [%d] %s\n" 10 "Invoice Sign · invoice"
    printf "  [%d] %s\n" 25 "Address Book · address"
    printf "  [%d] %s\n" 26 "Qr Codes · qr"
    printf "  [%d] %s\n" 27 "Telegram Bot · telegram"
    printf "  [%d] %s\n" 28 "Export · export"
    printf "  [%d] %s\n" 29 "Backup · backup"
    printf "  [%d] %s\n" 34 "Doc Scanner · ocr"
    printf "  [%d] %s\n" 35 "Cybra Guardian · guardian"
    printf "  [%d] %s\n" 36 "Auto Task Runner · system"
    printf "  [%d] %s\n" 37 "Multisig · multisig"
    printf "  [%d] %s\n" 38 "Timelock · timelock"
    printf "  [%d] %s\n" 39 "Contract Validator · contract"
    printf "  [%d] %s\n" 40 "Ai Analyze · ai"
    printf "  [%d] %s\n" 41 "Ai Parse Invoice · ai"
    printf "  [%d] %s\n" 42 "Ai Generate Terms · ai"
    printf "  [%d] %s\n" 43 "Ai Help · ai"
    printf "  [%d] %s\n" 44 "Ai Free Question · ai"
    printf "  [%d] %s\n" 45 "Ai Task Bar · ai"
    printf "  [%d] %s\n" 46 "Executor Full · evolution"
    printf "  [%d] %s\n" 47 "Executor Scan · evolution"
    printf "  [%d] %s\n" 48 "Executor Apply · evolution"
    printf "  [%d] %s\n" 49 "Executor List · evolution"
    printf "  [%d] %s\n" 50 "Address Add · address"
    printf "  [%d] %s\n" 51 "Address List · address"
    printf "  [%d] %s\n" 52 "Address History · address"
    printf "  [%d] %s\n" 53 "Qr Create · qr"
    printf "  [%d] %s\n" 54 "Telegram Setup · telegram"
    printf "  [%d] %s\n" 55 "Telegram Test · telegram"
    printf "  [%d] %s\n" 56 "Webhook List · webhook"
    printf "  [%d] %s\n" 57 "Webhook Add · webhook"
    printf "  [%d] %s\n" 58 "Csv Contracts · export"
    printf "  [%d] %s\n" 59 "Csv Ledger · export"
    printf "  [%d] %s\n" 60 "Txt Report · export"
    printf "  [%d] %s\n" 61 "Backup Local · backup"
    printf "  [%d] %s\n" 62 "Backup Cloud · backup"
    printf "  [%d] %s\n" 63 "Multichain List · multichain"
    printf "  [%d] %s\n" 64 "Scanner Tx · multichain"
    printf "  [%d] %s\n" 65 "Dispute Open · dispute"
    printf "  [%d] %s\n" 66 "Dispute List · dispute"
    printf "  [%d] %s\n" 67 "Dispute Vote · dispute"
    printf "  [%d] %s\n" 68 "Audit Log · audit"
    printf "  [%d] %s\n" 69 "Audit Verify · audit"
    printf "  [%d] %s\n" 70 "Ocr Photo · ocr"
    printf "  [%d] %s\n" 71 "Ocr Text · ocr"
    printf "  [%d] %s\n" 72 "Pdf To Text · ocr"
    printf "  [%d] %s\n" 73 "Ocr Pipeline · ocr"
    printf "  [%d] %s\n" 74 "Contract Search · contract"
    printf "  [%d] %s\n" 75 "Contract Autofill · contract"
    printf "  [%d] %s\n" 76 "Ai Terms Run · ai"
    printf "  [%d] %s\n" 77 "Payment Check · payment"
    printf "  [%d] %s\n" 78 "Contract Extra Terms · contract"
    printf "  [%d] %s\n" 79 "Watchdog · system"
    printf "  [%d] %s\n" 80 "Guardian Status · guardian"
    printf "  [%d] %s\n" 81 "Guardian 100Pct · guardian"
    printf "  [%d] %s\n" 82 "Register Identity · identity"
    printf "  [%d] %s\n" 83 "Show Identity · identity"
    printf "  [%d] %s\n" 84 "Verify Identity · identity"
    printf "  [%d] %s\n" 85 "Device Info · device"
    printf "  [%d] %s\n" 86 "Snapshot Create · snapshot"
    printf "  [%d] %s\n" 87 "Snapshot Git Restore · snapshot"
    printf "  [%d] %s\n" 88 "Snapshot Restore · snapshot"
    printf "  [%d] %s\n" 89 "Auto Recovery · guardian"
    printf "  [%d] %s\n" 90 "Action Log · audit"
    printf "  [%d] %s\n" 91 "Log Verify · audit"
    printf "  [%d] %s\n" 92 "Autosave Contract · autosave"
    printf "  [%d] %s\n" 93 "Autosave Status · autosave"
    printf "  [%d] %s\n" 94 "Autosave Archives · autosave"
    printf "  [%d] %s\n" 95 "Autosave Restore · autosave"
    printf "  [%d] %s\n" 96 "Evo7 · evolution"
    printf "  [%d] %s\n" 97 "Evo Controller · evolution"
    printf "  [%d] %s\n" 98 "Parawatch · parawatch"
    printf "  [%d] %s\n" 99 "Autopatch · system"
    printf "  [%d] %s\n" 100 "Node Manager · node"
    printf "  [%d] %s\n" 101 "Hash Ecosystem · hash"
    printf "  [%d] %s\n" 102 "Binmix · system"
    printf "  [%d] %s\n" 103 "Metrics · metrics"
    printf "  [%d] %s\n" 104 "Http Panel · system"
    printf "  [%d] %s\n" 105 "Schedule · schedule"
    printf "  [%d] %s\n" 106 "Cleanup · system"
    printf "  [%d] %s\n" 107 "Autopilot · system"
    printf "  [%d] %s\n" 108 "Metamask Sign · metamask"
    printf "  [%d] %s\n" 109 "Metamask Verify · metamask"
    printf "  [%d] %s\n" 110 "Metamask History · metamask"
    printf "  [%d] %s\n" 111 "Invoice · invoice"
    printf "  [%d] %s\n" 112 "Metamask Deeplink · metamask"
    printf "  [%d] %s\n" 113 "Metamask Batch · metamask"
    printf "  [%d] %s\n" 114 "Autonode · node"
    printf "  [%d] %s\n" 115 "Rpc Bench · rpc"
    printf "  [%d] %s\n" 116 "Gas Monitor · gas"
    printf "  [%d] %s\n" 117 "Tx Lookup · tx"
    printf "  [%d] %s\n" 118 "Net Health · net"
    printf "  [%d] %s\n" 119 "Qr Sign · qr"
    printf "  [%d] %s\n" 120 "Ai Guardian · ai"
    printf "  [%d] %s\n" 121 "Parliament · parliament"
    printf "  [%d] %s\n" 122 "Contract Validator V2 · contract"
    printf "  [%d] %s\n" 123 "Multisig V2 · multisig"
    printf "  [%d] %s\n" 124 "Timelock V2 · timelock"
    printf "  [%d] %s\n" 125 "Anchor · anchor"
    printf "  [%d] %s\n" 126 "Zk · zk"
    printf "  [%d] %s\n" 127 "Crosschain · multichain"
    printf "  [%d] %s\n" 128 "Dashboard · metrics"
    printf "  [%d] %s\n" 129 "Voice · voice"
    printf "  [%d] %s\n" 130 "Test Suite · test"
    printf "  [%d] %s\n" 131 "Kyc · kyc"
    printf "  [%d] %s\n" 132 "Compliance · compliance"
    printf "  [%d] %s\n" 133 "Tokens · token"
    printf "  [%d] %s\n" 134 "Discord · discord"
    printf "  [%d] %s\n" 135 "Walletconnect · wallet"
    printf "  [%d] %s\n" 136 "Templates · contract"
    printf "  [%d] %s\n" 137 "Escrow · escrow"
    printf "  [%d] %s\n" 138 "Arbitration · dispute"
    printf "  [%d] %s\n" 139 "Reputation · reputation"
    printf "  [%d] %s\n" 140 "Analytics · analytics"
    printf "  [%d] %s\n" 141 "Portfolio · portfolio"
    printf "  [%d] %s\n" 142 "Invoice Pdf · invoice"
    printf "  [%d] %s\n" 143 "Email Notif · email"
    printf "  [%d] %s\n" 144 "Lightning · lightning"
    printf "  [%d] %s\n" 145 "Ipfs · ipfs"
    printf "  [%d] %s\n" 146 "Merkle Batch · merkle"
    printf "  [%d] %s\n" 147 "Reputation V2 · reputation"
    printf "  [%d] %s\n" 148 "Multisig Ui · multisig"
    printf "  [%d] %s\n" 149 "Advanced Analytics · analytics"
    printf "  [%d] %s\n" 150 "Custom Scripts · custom"
    printf "  [%d] %s\n" 151 "Ad Contract · ad"
    printf "  [%d] %s\n" 152 "Rollback Evo · evolution"
    printf "  [%d] %s\n" 153 "Checkpoint · system"
    printf "  [%d] %s\n" 154 "Link Manager · integrations"
    printf "  [%d] %s\n" 155 "Mining Autofix · mining"
    printf "  [%d] %s\n" 156 "Chain Sync · blockchain"
    printf "  [%d] %s\n" 157 "Pool Monitor · pool"
    printf "  [%d] %s\n" 158 "Governance · governance"
    printf "  [%d] %s\n" 159 "Reports · reports"
    printf "  [%d] %s\n" 160 "Fidic Contracts · fidic"
    printf '%s\n' "  ${C_BOLD}[0]${C_RESET}  Вихід"
    printf '\n'
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
    esac
}

action_autopatch_menu() {
    printf '  [1] Dry-run\n'
    printf '  [2] Патчити все\n'
    printf '  [3] Тільки контракти\n'
    printf 'Вибір: '
    read -r ap
    case "$ap" in
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
    esac
}


while true; do
    print_header
    print_menu
    printf '  Вибір: '
    read -r CHOICE

    case "$CHOICE" in
        1) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_1_base/main.sh" ;;
        2) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_2_base/main.sh" ;;
        3) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_3_base/main.sh" ;;
        4) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_4_base/main.sh" ;;
        5) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_5_base/main.sh" ;;
        6) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_6_base/main.sh" ;;
        7) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_7_base/main.sh" ;;
        8) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_8_base/main.sh" ;;
        9) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_9_base/main.sh" ;;
        10) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_10_base/main.sh" ;;
        11) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_11_base/main.sh" ;;
        12) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_12_base/main.sh" ;;
        13) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_13_base/main.sh" ;;
        14) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_14_base/main.sh" ;;
        15) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_15_base/main.sh" ;;
        16) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_16_base/main.sh" ;;
        17) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_17_base/main.sh" ;;
        18) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_18_base/main.sh" ;;
        19) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_19_base/main.sh" ;;
        20) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_20_base/main.sh" ;;
        21) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_21_base/main.sh" ;;
        22) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_22_base/main.sh" ;;
        23) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_23_base/main.sh" ;;
        24) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_24_base/main.sh" ;;
        25) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_25_base/main.sh" ;;
        26) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_26_base/main.sh" ;;
        27) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_27_base/main.sh" ;;
        28) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_28_base/main.sh" ;;
        29) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_29_base/main.sh" ;;
        30) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_30_base/main.sh" ;;
        31) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_31_base/main.sh" ;;
        32) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_32_base/main.sh" ;;
        33) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_33_base/main.sh" ;;
        34) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_34_base/main.sh" ;;
        35) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_35_base/main.sh" ;;
        36) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_36_base/main.sh" ;;
        37) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_37_base/main.sh" ;;
        38) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_38_base/main.sh" ;;
        39) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_39_base/main.sh" ;;
        40) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_40_base/main.sh" ;;
        41) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_41_base/main.sh" ;;
        42) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_42_base/main.sh" ;;
        43) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_43_base/main.sh" ;;
        44) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_44_base/main.sh" ;;
        45) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_45_base/main.sh" ;;
        46) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_46_base/main.sh" ;;
        47) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_47_base/main.sh" ;;
        48) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_48_base/main.sh" ;;
        49) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_49_base/main.sh" ;;
        50) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_50_base/main.sh" ;;
        51) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_51_base/main.sh" ;;
        52) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_52_base/main.sh" ;;
        53) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_53_base/main.sh" ;;
        54) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_54_base/main.sh" ;;
        55) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_55_base/main.sh" ;;
        56) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_56_base/main.sh" ;;
        57) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_57_base/main.sh" ;;
        58) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_58_base/main.sh" ;;
        59) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_59_base/main.sh" ;;
        60) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_60_base/main.sh" ;;
        61) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_61_base/main.sh" ;;
        62) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_62_base/main.sh" ;;
        63) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_63_base/main.sh" ;;
        64) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_64_base/main.sh" ;;
        65) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_65_base/main.sh" ;;
        66) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_66_base/main.sh" ;;
        67) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_67_base/main.sh" ;;
        68) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_68_base/main.sh" ;;
        69) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_69_base/main.sh" ;;
        70) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_70_base/main.sh" ;;
        71) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_71_base/main.sh" ;;
        72) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_72_base/main.sh" ;;
        73) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_73_base/main.sh" ;;
        74) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_74_base/main.sh" ;;
        75) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_75_base/main.sh" ;;
        76) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_76_base/main.sh" ;;
        77) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_77_base/main.sh" ;;
        78) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_78_base/main.sh" ;;
        79) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_79_base/main.sh" ;;
        80) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_80_base/main.sh" ;;
        81) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_81_base/main.sh" ;;
        82) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_82_base/main.sh" ;;
        83) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_83_base/main.sh" ;;
        84) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_84_base/main.sh" ;;
        85) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_85_base/main.sh" ;;
        86) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_86_base/main.sh" ;;
        87) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_87_base/main.sh" ;;
        88) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_88_base/main.sh" ;;
        89) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_89_base/main.sh" ;;
        90) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_90_base/main.sh" ;;
        91) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_91_base/main.sh" ;;
        92) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_92_base/main.sh" ;;
        93) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_93_base/main.sh" ;;
        94) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_94_base/main.sh" ;;
        95) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_95_base/main.sh" ;;
        96) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_96_base/main.sh" ;;
        97) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_97_base/main.sh" ;;
        98) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_98_base/main.sh" ;;
        99) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_99_base/main.sh" ;;
        100) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_100_base/main.sh" ;;
        101) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_101_base/main.sh" ;;
        102) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_102_base/main.sh" ;;
        103) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_103_base/main.sh" ;;
        104) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_104_base/main.sh" ;;
        105) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_105_base/main.sh" ;;
        106) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_106_base/main.sh" ;;
        107) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_107_base/main.sh" ;;
        108) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_108_base/main.sh" ;;
        109) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_109_base/main.sh" ;;
        110) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_110_base/main.sh" ;;
        111) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_111_base/main.sh" ;;
        112) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_112_base/main.sh" ;;
        113) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_113_base/main.sh" ;;
        114) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_114_base/main.sh" ;;
        115) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_115_base/main.sh" ;;
        116) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_116_base/main.sh" ;;
        117) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_117_base/main.sh" ;;
        118) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_118_base/main.sh" ;;
        119) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_119_base/main.sh" ;;
        120) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_120_base/main.sh" ;;
        121) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_121_base/main.sh" ;;
        122) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_122_base/main.sh" ;;
        123) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_123_base/main.sh" ;;
        124) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_124_base/main.sh" ;;
        125) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_125_base/main.sh" ;;
        126) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_126_base/main.sh" ;;
        127) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_127_base/main.sh" ;;
        128) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_128_base/main.sh" ;;
        129) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_129_base/main.sh" ;;
        130) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_130_base/main.sh" ;;
        131) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_131_base/main.sh" ;;
        132) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_132_base/main.sh" ;;
        133) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_133_base/main.sh" ;;
        134) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_134_base/main.sh" ;;
        135) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_135_base/main.sh" ;;
        136) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_136_base/main.sh" ;;
        137) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_137_base/main.sh" ;;
        138) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_138_base/main.sh" ;;
        139) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_139_base/main.sh" ;;
        140) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_140_base/main.sh" ;;
        141) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_141_base/main.sh" ;;
        142) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_142_base/main.sh" ;;
        143) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_143_base/main.sh" ;;
        144) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_144_base/main.sh" ;;
        145) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_145_base/main.sh" ;;
        146) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_146_base/main.sh" ;;
        147) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_147_base/main.sh" ;;
        148) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_148_base/main.sh" ;;
        149) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_149_base/main.sh" ;;
        150) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_150_base/main.sh" ;;
        151) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_151_base/main.sh" ;;
        152) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_152_base/main.sh" ;;
        153) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_153_base/main.sh" ;;
        154) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_154_base/main.sh" ;;
        155) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_155_base/main.sh" ;;
        156) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_156_base/main.sh" ;;
        157) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_157_base/main.sh" ;;
        158) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_158_base/main.sh" ;;
        159) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_159_base/main.sh" ;;
        160) ~/CYBRA/controllers/module-controller.sh "/data/data/com.termux/files/home/CYBRA/modules/module_160_base/main.sh" ;;
        0|q|Q|exit|quit)
            printf "%s
" "${C_GREEN}До побачення.${C_RESET}"
            exit 0
            ;;
        *)
            printf "%s
" "${C_RED}Невідома опція.${C_RESET}"
            ;;
    esac
    printf '\n%s\n' "${C_GREY}Enter — продовжити${C_RESET}"
    read -r _
done
