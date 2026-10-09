#!/data/data/com.termux/files/usr/bin/bash

CYBRA_MOD19_ROOT="$HOME/CYBRA/modules/module_19_contract_tui_menu"
source "$CYBRA_MOD19_ROOT/bin/cybra_tui_lib.sh"

print_header() {
    clear 2>/dev/null || printf '\033[2J\033[H'
    printf '%s\n' "${C_BOLD}${C_CYAN}============================================================${C_RESET}"
    printf '%s\n' "${C_BOLD}${C_CYAN}        CYBRA CONTRACT MANAGER — TUI v1.0${C_RESET}"
    printf '%s\n' "${C_BOLD}${C_CYAN}============================================================${C_RESET}"
    printf '%s\n' "${C_GREY}  CHAIN: BSC (56)   LICENSE: 1%   RECIPIENT: ${LICENSE_RECIPIENT:0:10}...${C_RESET}"
    printf '\n'
}

print_menu() {
    printf '%s\n' "  ${C_BOLD}[1]${C_RESET} Створити новий контракт"
    printf '%s\n' "  ${C_BOLD}[2]${C_RESET} Список усіх контрактів"
    printf '%s\n' "  ${C_BOLD}[3]${C_RESET} Статус контракту"
    printf '%s\n' "  ${C_BOLD}[4]${C_RESET} Згенерувати лінки (BUYER / SELLER / RECEIPT)"
    printf '%s\n' "  ${C_BOLD}[5]${C_RESET} Підтвердити лінк"
    printf '%s\n' "  ${C_BOLD}[6]${C_RESET} Debug — повний лог контракту"
    printf '%s\n' "  ${C_BOLD}[7]${C_RESET} Ліцензійний реєстр (1% з усіх контрактів)"
    printf '%s\n' "  ${C_BOLD}[8]${C_RESET} Hardening — перевірка системи"
    printf '%s\n' "  ${C_BOLD}[0]${C_RESET} Вихід"
    printf '\n'
}

action_create_contract() {
    printf '%s\n' "${C_BOLD}--- Створити контракт ---${C_RESET}"

    printf 'BUYER wallet:  '; read -r BUYER
    printf 'SELLER wallet: '; read -r SELLER
    printf 'AMOUNT (wei):  '; read -r AMOUNT
    printf 'TOKEN (адреса або BNB): '; read -r TOKEN
    TOKEN="${TOKEN:-BNB}"

    if [ -z "$BUYER" ] || [ -z "$SELLER" ] || [ -z "$AMOUNT" ]; then
        printf '%s\n' "${C_RED}Помилка: BUYER, SELLER, AMOUNT обов'\''язкові${C_RESET}"
        return 1
    fi

    local cid
    cid="$(cybra_contract_create "$BUYER" "$SELLER" "$AMOUNT" "$TOKEN")"

    if [ -z "$cid" ]; then
        printf '%s\n' "${C_RED}Помилка створення контракту${C_RESET}"
        return 1
    fi

    printf '%s\n' "${C_GREEN}OK: контракт створено${C_RESET}"
    printf 'ID: %s\n' "$cid"
    printf 'Ліцензія: %s wei (%s%%)\n' \
        "$(cybra_calc_license "$AMOUNT")" "$LICENSE_PERCENT"
    printf 'Отримувач ліцензії: %s\n' "$LICENSE_RECIPIENT"
}

action_list_contracts() {
    printf '%s\n' "${C_BOLD}--- Список контрактів ---${C_RESET}"
    printf '\n'

    local found=0
    for f in "$CYBRA_CONTRACTS"/*.env; do
        [ -f "$f" ] || continue
        found=1
        local cid="$(grep '^CONTRACT_ID=' "$f" | cut -d= -f2)"
        local stage="$(grep '^STAGE=' "$f" | cut -d= -f2)"
        local amount="$(grep '^AMOUNT_WEI=' "$f" | cut -d= -f2)"
        local lic="$(grep '^LICENSE_WEI=' "$f" | cut -d= -f2)"
        printf '  %s %s  amount=%s  license=%s\n' \
            "$(printf '%-32s' "$cid")" \
            "$(printf '%-12s' "[$stage]")" \
            "$amount" "$lic"
    done

    if [ "$found" -eq 0 ]; then
        printf '%s\n' "${C_YELLOW}(порожньо)${C_RESET}"
    fi
}

action_show_status() {
    printf 'CONTRACT_ID: '; read -r CID

    if ! cybra_contract_exists "$CID"; then
        printf '%s\n' "${C_RED}Контракт не знайдено${C_RESET}"
        return 1
    fi

    local f="$(cybra_contract_path "$CID")"

    printf '\n%s\n' "${C_BOLD}--- Контракт: $CID ---${C_RESET}"
    printf '\n'
    printf '  %-24s %s\n' "STAGE:"        "$(grep '^STAGE=' "$f" | cut -d= -f2)"
    printf '  %-24s %s\n' "STATUS:"       "$(grep '^STATUS=' "$f" | cut -d= -f2)"
    printf '  %-24s %s\n' "BUYER:"        "$(grep '^BUYER=' "$f" | cut -d= -f2)"
    printf '  %-24s %s\n' "SELLER:"       "$(grep '^SELLER=' "$f" | cut -d= -f2)"
    printf '  %-24s %s\n' "AMOUNT_WEI:"   "$(grep '^AMOUNT_WEI=' "$f" | cut -d= -f2)"
    printf '  %-24s %s\n' "LICENSE_WEI:"  "$(grep '^LICENSE_WEI=' "$f" | cut -d= -f2)"
    printf '  %-24s %s\n' "NET_WEI:"      "$(grep '^NET_WEI=' "$f" | cut -d= -f2)"
    printf '\n'
    printf '  %-24s %s\n' "BUYER_CONFIRMED:"   "$(grep '^BUYER_CONFIRMED=' "$f" | cut -d= -f2)"
    printf '  %-24s %s\n' "SELLER_CONFIRMED:"  "$(grep '^SELLER_CONFIRMED=' "$f" | cut -d= -f2)"
    printf '  %-24s %s\n' "RECEIPT_CONFIRMED:" "$(grep '^RECEIPT_CONFIRMED=' "$f" | cut -d= -f2)"
    printf '\n'
    printf '  %-24s %s\n' "BUYER_LINK:"   "$(grep '^BUYER_LINK_ID=' "$f" | cut -d= -f2)"
    printf '  %-24s %s\n' "SELLER_LINK:"  "$(grep '^SELLER_LINK_ID=' "$f" | cut -d= -f2)"
    printf '  %-24s %s\n' "RECEIPT_LINK:" "$(grep '^RECEIPT_LINK_ID=' "$f" | cut -d= -f2)"
}

action_generate_links() {
    printf 'CONTRACT_ID: '; read -r CID

    if ! cybra_contract_exists "$CID"; then
        printf '%s\n' "${C_RED}Контракт не знайдено${C_RESET}"
        return 1
    fi

    printf '%s\n' "${C_BOLD}Генерую 3 лінки...${C_RESET}"

    local bl sl rl
    bl="$(cybra_link_generate "$CID" BUYER)"
    sl="$(cybra_link_generate "$CID" SELLER)"
    rl="$(cybra_link_generate "$CID" RECEIPT)"

    printf '\n'
    printf '%s\n' "${C_GREEN}--- Лінк покупця (підтвердження транзакції) ---${C_RESET}"
    printf '  ID:   %s\n' "$bl"
    printf '  Шлях: %s\n' "$(cybra_link_path "$bl")"

    printf '\n'
    printf '%s\n' "${C_GREEN}--- Лінк продавця (отримання оплати) ---${C_RESET}"
    printf '  ID:   %s\n' "$sl"
    printf '  Шлях: %s\n' "$(cybra_link_path "$sl")"

    printf '\n'
    printf '%s\n' "${C_GREEN}--- Лінк отримання товару (покупець) ---${C_RESET}"
    printf '  ID:   %s\n' "$rl"
    printf '  Шлях: %s\n' "$(cybra_link_path "$rl")"

    printf '\n%s\n' "${C_YELLOW}Надішли кожен лінк відповідній стороні.${C_RESET}"
}

action_confirm_link() {
    printf 'LINK_ID: '; read -r LID
    printf 'CONFIRMED_BY (wallet): '; read -r WHO

    if [ -z "$LID" ] || [ -z "$WHO" ]; then
        printf '%s\n' "${C_RED}Помилка: LINK_ID і CONFIRMED_BY обов'\''язкові${C_RESET}"
        return 1
    fi

    local out
    out="$(cybra_link_confirm "$LID" "$WHO")"

    if [ "$?" -ne 0 ]; then
        printf '%s\n' "${C_RED}$out${C_RESET}"
        return 1
    fi

    printf '%s\n' "${C_GREEN}$out${C_RESET}"
}

action_debug() {
    printf 'CONTRACT_ID: '; read -r CID

    if ! cybra_contract_exists "$CID"; then
        printf '%s\n' "${C_RED}Контракт не знайдено${C_RESET}"
        return 1
    fi

    printf '\n%s\n' "${C_BOLD}--- DEBUG LOG (останні 30) ---${C_RESET}"
    grep "$CID" "$CYBRA_DEBUG" 2>/dev/null | tail -30

    printf '\n%s\n' "${C_BOLD}--- Всі лінки цього контракту ---${C_RESET}"
    for lf in "$CYBRA_LINKS"/*.link; do
        [ -f "$lf" ] || continue
        local c="$(grep '^CONTRACT_ID=' "$lf" | cut -d= -f2)"
        [ "$c" = "$CID" ] || continue
        printf '  %s  role=%s  status=%s\n' \
            "$(basename "$lf" .link)" \
            "$(grep '^ROLE=' "$lf" | cut -d= -f2)" \
            "$(grep '^STATUS=' "$lf" | cut -d= -f2)"
    done
}

action_license_ledger() {
    printf '%s\n' "${C_BOLD}--- Ліцензійний реєстр (1% з кожного контракту) ---${C_RESET}"
    printf '%s\n' "${C_GREY}Формат: TIMESTAMP | CONTRACT | AMOUNT | LICENSE | RECIPIENT${C_RESET}"
    printf '\n'

    if [ -f "$CYBRA_LICENSE_LEDGER" ]; then
        cat "$CYBRA_LICENSE_LEDGER"
        printf '\n%s\n' "${C_BOLD}Всього контрактів:${C_RESET} $(wc -l < "$CYBRA_LICENSE_LEDGER")"
    else
        printf '%s\n' "${C_YELLOW}(порожньо)${C_RESET}"
    fi
}

action_creation_license() {
    printf '%s
' "${C_BOLD}--- CREATION LICENSE LEDGER ---${C_RESET}"
    printf '%s
' "${C_GREY}Плата за створення контракту:${C_RESET}"
    printf '%s
' "${C_GREY}  Фіксована: ${CREATION_FEE_FIXED_WEI:-0} wei${C_RESET}"
    printf '%s
' "${C_GREY}  Відсоток: ${CREATION_FEE_PERCENT:-1}%%${C_RESET}"
    printf '%s
' "${C_GREY}  Отримувач: ${CREATION_FEE_RECIPIENT:0:10}...${C_RESET}"
    printf '
'

    if [ -f "$CREATION_LICENSE_LEDGER" ]; then
        cat "$CREATION_LICENSE_LEDGER"
        printf '
%s
' "${C_BOLD}Всього контрактів:${C_RESET} $(wc -l < "$CREATION_LICENSE_LEDGER")"
    else
        printf '%s
' "${C_YELLOW}(порожньо)${C_RESET}"
    fi
}

action_dual_license_ledger() {
    printf '%s
' "${C_BOLD}--- DUAL-LICENSE LEDGER ---${C_RESET}"
    printf '%s
' "${C_GREY}LICENSE_A: 1% → ${LICENSE_A_RECIPIENT:0:10}...${C_RESET}"
    printf '%s
' "${C_GREY}LICENSE_B: 1% → ${LICENSE_B_RECIPIENT:0:10}...${C_RESET}"
    printf '
'

    if [ -f "$CYBRA_LICENSE_LEDGER" ]; then
        printf '%s
' "${C_BOLD}--- LEDGER A ---${C_RESET}"
        cat "$CYBRA_LICENSE_LEDGER"
        printf '
%s
' "${C_BOLD}Записів A:${C_RESET} $(wc -l < "$CYBRA_LICENSE_LEDGER")"
    fi

    if [ -f "$CYBRA_LICENSE_LEDGER_B" ]; then
        printf '
%s
' "${C_BOLD}--- LEDGER B ---${C_RESET}"
        cat "$CYBRA_LICENSE_LEDGER_B"
        printf '
%s
' "${C_BOLD}Записів B:${C_RESET} $(wc -l < "$CYBRA_LICENSE_LEDGER_B")"
    fi
}

action_hardening() {
    printf '%s\n' "${C_BOLD}--- Запуск hardening ---${C_RESET}"
    if [ -x "$HOME/CYBRA/cybra_mega_hardening.sh" ]; then
        "$HOME/CYBRA/cybra_mega_hardening.sh"
    else
        printf '%s\n' "${C_RED}cybra_mega_hardening.sh не знайдено${C_RESET}"
    fi
}

# ------------------------------------------------------------
# Main loop
# ------------------------------------------------------------

while true; do
    print_header
    print_menu

    printf '%s' "  Вибір: "
    read -r CHOICE

    printf '\n'

    case "$CHOICE" in
        1) action_create_contract ;;
        2) action_list_contracts ;;
        3) action_show_status ;;
        4) action_generate_links ;;
        5) action_confirm_link ;;
        6) action_debug ;;
        7) action_license_ledger ;;
        8) action_hardening ;;
        9) action_dual_license_ledger ;;
        10) action_creation_license ;;
        0|q|Q|exit|quit)
            printf '%s\n' "${C_GREEN}До побачення.${C_RESET}"
            exit 0
            ;;
        *)
            printf '%s\n' "${C_RED}Невідома опція.${C_RESET}"
            ;;
    esac

    printf '\n'
    printf '%s' "${C_GREY}Enter для продовження...${C_RESET}"
    read -r _
done
