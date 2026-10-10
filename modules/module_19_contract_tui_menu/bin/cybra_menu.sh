#!/data/data/com.termux/files/usr/bin/bash

source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_health.sh" 2>/dev/null || true

source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_local_ai.sh" 2>/dev/null || true

CYBRA_MOD19_ROOT="$HOME/CYBRA/modules/module_19_contract_tui_menu"
source "$CYBRA_MOD19_ROOT/bin/cybra_tui_lib.sh"

action_create_invoice() {
    printf '%s\n' "${C_BOLD}--- Створити INVOICE-контракт ---${C_RESET}"
    printf '%s\n' "${C_GREY}Повний рахунок: сторони + позиції + умови + 3 лінки${C_RESET}"
    printf '\n'

    printf 'ПІБ покупця:    '; read -r BUYER_NAME
    printf 'ІПН покупця:    '; read -r BUYER_IPN
    printf 'Wallet покупця: '; read -r BUYER_WALLET

    printf 'Назва продавця: '; read -r SELLER_NAME
    printf 'ЄДРПОУ:         '; read -r SELLER_EDRPOU
    printf 'Wallet продавця: '; read -r SELLER_WALLET

    printf 'Номер рахунку:  '; read -r INV_NO
    printf 'Дата рахунку:   '; read -r INV_DATE
    printf 'Сума в токені:  '; read -r AMOUNT_RAW
    printf 'Token contract: '; read -r TOKEN
    printf 'Decimals [18]:  '; read -r DECIMALS
    DECIMALS="${DECIMALS:-18}"

    AMOUNT="$(cybra_amount_to_wei "$AMOUNT_RAW" "$DECIMALS")"

    if [ -z "$BUYER_NAME" ] || [ -z "$SELLER_NAME" ] || [ -z "$AMOUNT" ] || [ "$AMOUNT" = "0" ]; then
        printf '%s\n' "${C_RED}Помилка: всі поля обов'язкові${C_RESET}"
        return 1
    fi

    local cid
    cid="$(cybra_contract_create_invoice \
        "$BUYER_NAME" "$BUYER_IPN" "$BUYER_WALLET" \
        "$SELLER_NAME" "$SELLER_EDRPOU" "$SELLER_WALLET" \
        "$INV_NO" "$INV_DATE" "$AMOUNT" "$TOKEN" "$DECIMALS" 20)"

    if [ -z "$cid" ]; then
        printf '%s\n' "${C_RED}Не вдалось створити${C_RESET}"; return 1
    fi

    printf '\n%s\n' "${C_GREEN}OK: створено $cid${C_RESET}"
    printf 'CONTRACT_ID: %s\n' "$cid"
}

action_add_line() {
    printf 'CONTRACT_ID: '; read -r CID
    [ ! -f "$(cybra_contract_path "$CID")" ] && {
        printf '%s\n' "${C_RED}Контракт не знайдено${C_RESET}"; return 1
    }
    printf 'Код:      '; read -r CODE
    printf 'Назва:    '; read -r NAME
    printf 'Кількість: '; read -r QTY
    printf 'Ціна:     '; read -r PRICE
    local sum
    sum="$(cybra_invoice_add_line "$CID" "$CODE" "$NAME" "$QTY" "$PRICE")"
    printf '%s\n' "${C_GREEN}Додано: $NAME x$QTY = $sum${C_RESET}"
}

action_show_invoice() {
    printf 'CONTRACT_ID: '; read -r CID
    cybra_invoice_show "$CID"
}

action_finalize_invoice() {
    printf 'CONTRACT_ID: '; read -r CID
    local result
    result="$(cybra_invoice_finalize "$CID")"
    [ $? -ne 0 ] && { printf '%s\n' "${C_RED}$result${C_RESET}"; return 1; }
    printf '%s\n' "${C_GREEN}OK: finalized${C_RESET}"
    printf '%s\n' "$result"
}

action_export_masked() {
    printf 'CONTRACT_ID: '; read -r CID
    [ -z "$CID" ] && return 1
    [ ! -f "$(cybra_contract_path "$CID")" ] && {
        printf '%s\n' "${C_RED}Контракт не знайдено${C_RESET}"; return 1
    }
    local out_dir="$HOME/CYBRA/public/contracts"
    local h="$(cybra_export_masked "$CID" "$out_dir")"
    printf '%s\n' "${C_GREEN}OK: PII-masked export${C_RESET}"
    printf '  Export hash: %s\n' "$h"
    printf '  Path: %s\n' "$out_dir"
}

action_export_all_masked() {
    local out_dir="$HOME/CYBRA/public/contracts"
    printf '%s\n' "${C_BOLD}--- Експорт усіх контрактів (PII-masked) ---${C_RESET}"
    cybra_export_all_masked "$out_dir"
    if [ -d "$HOME/CYBRA/git_module/.git" ]; then
        printf '\nПуш у git? [y/N]: '; read -r PUSH_ANS
        if [ "$PUSH_ANS" = "y" ] || [ "$PUSH_ANS" = "Y" ]; then
            mkdir -p "$HOME/CYBRA/git_module/contracts"
            cp -r "$out_dir"/* "$HOME/CYBRA/git_module/contracts/" 2>/dev/null || true
            cd "$HOME/CYBRA/git_module" || return 1
            git add -A
            git commit -m "PII-masked contracts $(date -u +%Y%m%dT%H%M%SZ)" 2>/dev/null || true
            git push 2>&1 | tail -3
        fi
    fi
}

action_verify_pii() {
    printf 'Значення: '; read -r VALUE
    printf 'Hash:     '; read -r EXPECTED
    local computed="$(cybra_pii_hash "$VALUE")"
    printf 'Computed: %s\n' "$computed"
    [ "$computed" = "$EXPECTED" ] && printf '%s\n' "${C_GREEN}MATCH${C_RESET}" || printf '%s\n' "${C_RED}MISMATCH${C_RESET}"
}

action_buyer_final_decision() {
    printf '%s\n' "${C_BOLD}--- Фінальне рішення покупця ---${C_RESET}"
    printf 'CONTRACT_ID: '; read -r CID
    [ ! -f "$(cybra_contract_path "$CID")" ] && { printf '%s\n' "${C_RED}Not found${C_RESET}"; return 1; }

    cybra_refund_status "$CID"
    printf '\n'
    printf 'Рішення [CONFIRMED/REJECTED]: '; read -r DEC
    printf 'Wallet покупця (для перевірки): '; read -r W

    cybra_buyer_final_decision "$CID" "$DEC" "$W"
}

action_check_timeouts() {
    printf '%s\n' "${C_BOLD}--- Перевірка timeout всіх контрактів ---${C_RESET}"
    cybra_check_all_refunds
}

action_refund_status() {
    printf 'CONTRACT_ID: '; read -r CID
    cybra_refund_status "$CID"
}

action_add_term() {
    printf 'CONTRACT_ID: '; read -r CID
    printf 'Додаткова умова: '; read -r TERM
    cybra_add_custom_term "$CID" "$TERM"
}

action_show_rates() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh"
    cybra_show_rates
}

action_update_rate() {
    printf 'RATE_KEY (наприклад RATE_USD_UAH): '; read -r KEY
    printf 'VALUE: '; read -r VAL
    local rf="$HOME/CYBRA/modules/module_19_contract_tui_menu/state/rates.env"
    if grep -q "^${KEY}=" "$rf"; then
        sed -i "s|^${KEY}=.*|${KEY}=${VAL}|" "$rf"
    else
        printf '%s=%s\n' "$KEY" "$VAL" >> "$rf"
    fi
    printf '%s\n' "${C_GREEN}OK${C_RESET}"
}

action_convert() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh"
    printf 'Сума: '; read -r AMT
    printf 'З валюти (USD/UAH/EUR/CYBRA): '; read -r FROM
    printf 'У валюту (USD/UAH/EUR/CYBRA): '; read -r TO

    FROM="$(printf '%s' "$FROM" | tr '[:lower:]' '[:upper:]')"
    TO="$(printf '%s' "$TO" | tr '[:lower:]' '[:upper:]')"

    case "${FROM}_${TO}" in
        *_CYBRA)
            local wei="$(cybra_currency_to_cybra "$AMT" "$FROM" 18)"
            local dec="$(awk -v w="$wei" 'BEGIN { printf "%.6f", w / 1000000000000000000 }')"
            printf '  %s %s = %s CYBRA (wei: %s)\n' "$AMT" "$FROM" "$dec" "$wei"
            ;;
        CYBRA_*)
            printf '  Введи wei: '; read -r WEI
            local res="$(cybra_cybra_to_currency "$WEI" "$TO" 18)"
            printf '  %s wei = %s %s\n' "$WEI" "$res" "$TO"
            ;;
        *)
            printf '  Пряма конвертація не підтримується, використовуй через USD\n'
            ;;
    esac
}

action_preflight() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_preflight.sh"
    cybra_preflight
}

action_self_heal() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_self_heal.sh"
    cybra_self_heal
}

action_dual_verify() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh"
    printf 'CONTRACT_ID: '; read -r CID
    printf 'Computed hash...\n'
    cybra_contract_compute_dual_hash "$CID" >/dev/null
    local v="$(cybra_contract_verify_dual "$CID")"
    printf 'Result: %s\n' "$v"
}

action_ownership() {
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh"
    cybra_ownership_scan
}

print_header() {
    clear 2>/dev/null || printf '[2J[H'

    local SYS=$(h_system 2>/dev/null)
    local ICON_SYS=$(cybra_icon "$SYS")
    local LABEL_SYS=$(cybra_icon_label "$SYS")

    local n_mod=$(h_stat_modules 2>/dev/null)
    local n_con=$(h_stat_contracts 2>/dev/null)
    local n_lnk=$(h_stat_links 2>/dev/null)
    local now=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

    printf '%s
' "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════${C_RESET}"
    printf '%s
' "${C_BOLD}${C_CYAN}              CYBRA CONTRACT MANAGER — TUI v1.1${C_RESET}"
    printf '%s
' "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════${C_RESET}"
    printf '  %s %s  │  BSC(56)  │  1%%+1%%+1%% license
' "$ICON_SYS" "$LABEL_SYS"
    printf '  %s modules  │  %s contracts  │  %s links
' "$n_mod" "$n_con" "$n_lnk"
    printf '%s
' "  ${C_GREY}🕐 $now${C_RESET}"
    printf '%s
' "${C_GREY}────────────────────────────────────────────────────────────${C_RESET}"
    printf '
'
}

print_menu() {
    printf '%s
' "${C_BOLD}  ─── ОСНОВНЕ ───${C_RESET}"
    printf "  %s ${C_BOLD}[1]${C_RESET}  Створити контракт
" "$(cybra_icon $(h_create))"
    printf "  %s ${C_BOLD}[2]${C_RESET}  Список контрактів
" "$(cybra_icon $(h_list))"
    printf "  %s ${C_BOLD}[3]${C_RESET}  Статус контракту
" "$(cybra_icon $(h_status))"
    printf "  %s ${C_BOLD}[4]${C_RESET}  Згенерувати лінки
" "$(cybra_icon $(h_links_gen))"
    printf "  %s ${C_BOLD}[5]${C_RESET}  Підтвердити лінк
" "$(cybra_icon $(h_links_confirm))"
    printf "  %s ${C_BOLD}[6]${C_RESET}  Debug
" "$(cybra_icon $(h_debug))"
    printf "  %s ${C_BOLD}[7]${C_RESET}  DUAL-LICENSE ledger
" "$(cybra_icon $(h_ledger_a))"
    printf "  %s ${C_BOLD}[8]${C_RESET}  CREATION-LICENSE ledger
" "$(cybra_icon $(h_ledger_b))"
    printf "  %s ${C_BOLD}[9]${C_RESET}  Hardening
" "$(cybra_icon $(h_hardening))"
    printf '
'

    printf '%s
' "${C_CYAN}  ─── INVOICE ───${C_RESET}"
    printf "  %s ${C_BOLD}[11]${C_RESET} Створити INVOICE
" "$(cybra_icon $(h_invoice_create))"
    printf "  %s ${C_BOLD}[12]${C_RESET} Додати позицію
" "$(cybra_icon $(h_invoice_line))"
    printf "  %s ${C_BOLD}[13]${C_RESET} Показати INVOICE
" "$(cybra_icon $(h_invoice_show))"
    printf "  %s ${C_BOLD}[14]${C_RESET} Фіналізувати INVOICE
" "$(cybra_icon $(h_invoice_final))"
    printf '
'

    printf '%s
' "${C_CYAN}  ─── PII / CURRENCY ───${C_RESET}"
    printf "  🟢 ${C_BOLD}[15]${C_RESET} Експорт PII-masked
"
    printf "  🟢 ${C_BOLD}[16]${C_RESET} Експорт + git
"
    printf "  🟢 ${C_BOLD}[17]${C_RESET} Перевірити PII хеш
"
    printf "  🟢 ${C_BOLD}[22]${C_RESET} Курси валют
"
    printf "  🟢 ${C_BOLD}[23]${C_RESET} Оновити курс
"
    printf "  🟢 ${C_BOLD}[24]${C_RESET} Конвертер
"
    printf '
'

    printf '%s
' "${C_CYAN}  ─── REFUND ───${C_RESET}"
    printf "  %s ${C_BOLD}[18]${C_RESET} Фінальне рішення покупця
" "$(cybra_icon $(h_refund_decision))"
    printf "  %s ${C_BOLD}[19]${C_RESET} Перевірити timeout
" "$(cybra_icon $(h_refund_timeout))"
    printf "  %s ${C_BOLD}[20]${C_RESET} Статус refund
" "$(cybra_icon $(h_refund_status))"
    printf "  %s ${C_BOLD}[21]${C_RESET} Додати умову
" "$(cybra_icon $(h_refund_term))"
    printf '
'

    printf '%s
' "${C_GREEN}  ─── ADDRESS BOOK ───${C_RESET}"
    printf "  🟢 ${C_BOLD}[50]${C_RESET} Додати адресу
"
    printf "  🟢 ${C_BOLD}[51]${C_RESET} Список адрес
"
    printf "  🟢 ${C_BOLD}[52]${C_RESET} Історія адрес
"
    printf '
'

    printf '%s
' "${C_GREEN}  ─── INTEGRATIONS ───${C_RESET}"
    printf "  🟢 ${C_BOLD}[53]${C_RESET} QR-код для лінку
"
    printf "  🟢 ${C_BOLD}[54]${C_RESET} Telegram — налаштувати
"
    printf "  🟢 ${C_BOLD}[55]${C_RESET} Telegram — тест
"
    printf "  🟢 ${C_BOLD}[56]${C_RESET} Webhook — список
"
    printf "  🟢 ${C_BOLD}[57]${C_RESET} Webhook — додати
"
    printf '
'

    printf '%s
' "${C_GREEN}  ─── EXPORT / BACKUP ───${C_RESET}"
    printf "  🟢 ${C_BOLD}[58]${C_RESET} CSV — контракти
"
    printf "  🟢 ${C_BOLD}[59]${C_RESET} CSV — ledger
"
    printf "  🟢 ${C_BOLD}[60]${C_RESET} TXT — звіт контракту
"
    printf "  🟢 ${C_BOLD}[61]${C_RESET} Backup — локальний
"
    printf "  🟢 ${C_BOLD}[62]${C_RESET} Backup — в хмару (rclone)
"
    printf '
'

    printf '%s
' "${C_GREEN}  ─── MULTI-CHAIN ───${C_RESET}"
    printf "  🟢 ${C_BOLD}[63]${C_RESET} Список мереж
"
    printf "  🟢 ${C_BOLD}[64]${C_RESET} Сканер-tx link
"
    printf '
'

    printf '%s
' "${C_RED}  ─── DISPUTE / AUDIT ───${C_RESET}"
    printf "  🟢 ${C_BOLD}[65]${C_RESET} Відкрити спір
"
    printf "  🟢 ${C_BOLD}[66]${C_RESET} Список спорів
"
    printf "  🟢 ${C_BOLD}[67]${C_RESET} Голосувати
"
    printf "  🟢 ${C_BOLD}[68]${C_RESET} Audit log — показати
"
    printf "  🟢 ${C_BOLD}[69]${C_RESET} Audit log — перевірити
"
    printf '
'

    printf '%s
' "${C_RED}  ─── DOCUMENT SCANNER ───${C_RESET}"
    printf "  🟢 ${C_BOLD}[70]${C_RESET} Сфотографувати
"
    printf "  🟢 ${C_BOLD}[71]${C_RESET} OCR (фото → текст)
"
    printf "  🟢 ${C_BOLD}[72]${C_RESET} PDF → текст
"
    printf "  🟢 ${C_BOLD}[73]${C_RESET} Повний pipeline
"
    printf '
'

    printf '%s
' "${C_MAGENTA}  ─── SYSTEM ───${C_RESET}"
    printf "  %s ${C_BOLD}[30]${C_RESET} Preflight
" "$(cybra_icon $(h_preflight))"
    printf "  %s ${C_BOLD}[31]${C_RESET} Self-heal
" "$(cybra_icon $(h_self_heal))"
    printf "  %s ${C_BOLD}[32]${C_RESET} Dual-backend verify
" "$(cybra_icon $(h_dual_verify))"
    printf "  %s ${C_BOLD}[33]${C_RESET} Ownership scan
" "$(cybra_icon $(h_ownership))"
    printf '
'

    printf '%s
' "${C_MAGENTA}  ─── AI ───${C_RESET}"
    printf "  🟢 ${C_BOLD}[40]${C_RESET} AI Аналіз
"
    printf "  🟢 ${C_BOLD}[41]${C_RESET} AI Парсинг рахунку
"
    printf "  🟢 ${C_BOLD}[42]${C_RESET} AI Генерація умов
"
    printf "  🟢 ${C_BOLD}[43]${C_RESET} AI Допомога
"
    printf "  🟢 ${C_BOLD}[44]${C_RESET} AI Питання
"
    printf "  🟢 ${C_BOLD}[45]${C_RESET} AI Task Bar
"
    printf '
'

    printf '%s
' "${C_MAGENTA}  ─── AI EVOLUTION ───${C_RESET}"
    printf "  🟢 ${C_BOLD}[46]${C_RESET} Executor — повний
"
    printf "  🟢 ${C_BOLD}[47]${C_RESET} Executor — scan
"
    printf "  🟢 ${C_BOLD}[48]${C_RESET} Executor — apply
"
    printf "  🟢 ${C_BOLD}[49]${C_RESET} Executor — список
"
    printf '
'

    printf '%s
' "  ${C_GREY}🟢 ready  🟡 warning  🔴 error${C_RESET}"
    printf '
'
    printf '%s
' "  ${C_BOLD}[0]${C_RESET}  Вихід"
    printf '
'
}

action_ai_executor_full() {
    "$HOME/CYBRA/ai/cybra_ai_executor.sh" full
}
action_ai_executor_scan() {
    "$HOME/CYBRA/ai/cybra_ai_executor.sh" scan
}
action_ai_executor_apply() {
    "$HOME/CYBRA/ai/cybra_ai_executor.sh" apply
}
action_ai_executor_list() {
    "$HOME/CYBRA/ai/cybra_ai_executor.sh" list
}

action_ai_review() {
    action_list_contracts
    printf 'CONTRACT_ID: '; read -r CID
    [ -z "$CID" ] && return 1
    local_ai_review_contract "$CID"
}

action_ai_parse_invoice() {
    local_ai_parse_invoice
}

action_ai_generate_terms() {
    action_list_contracts
    printf 'CONTRACT_ID: '; read -r CID
    [ -z "$CID" ] && return 1
    local_ai_generate_terms "$CID"
}

action_ai_help_error() {
    printf 'Помилка (встав текст): '
    read -r ERR
    [ -z "$ERR" ] && return 1
    local_ai_help_error "$ERR"
}

action_ai_ask() {
    printf 'Питання: '
    read -r Q
    [ -z "$Q" ] && return 1
    local_ai_answer "$Q"
}

action_ai_taskbar() {
    if [ -x "$HOME/CYBRA/CYBRA_AI_TASK_BAR.sh" ]; then
        "$HOME/CYBRA/CYBRA_AI_TASK_BAR.sh"
    else
        printf '%s%s%s
' "${C_RED:-}" "AI Task Bar не знайдено" "${C_RESET:-}"
        printf 'Запусти: cybra_self_heal
'
        read -r _
    fi
}

action_create_contract() {
    printf '%s
' "${C_BOLD}--- Створити контракт ---${C_RESET}"
    printf '%s
' "${C_GREY}Сума вказується в одиницях токена (наприклад 100 або 100.5)${C_RESET}"
    printf '%s
' "${C_GREY}Decimals: 18 (BEP-20 стандарт), 6 (USDT), 8 (WBTC) і т.д.${C_RESET}"
    printf '
'

    printf 'BUYER wallet:  '; read -r BUYER
    printf 'SELLER wallet: '; read -r SELLER
    printf 'AMOUNT (в токенах): '; read -r AMOUNT_RAW
    printf 'TOKEN address (0x...): '; read -r TOKEN
    printf 'TOKEN_DECIMALS [18]: '; read -r DECIMALS
    DECIMALS="${DECIMALS:-18}"

    if [ -z "$BUYER" ] || [ -z "$SELLER" ] || [ -z "$AMOUNT_RAW" ] || [ -z "$TOKEN" ]; then
        printf '%s
' "${C_RED}Помилка: всі поля обов'''язкові${C_RESET}"
        return 1
    fi

    if ! [[ "$DECIMALS" =~ ^[0-9]+$ ]]; then
        printf '%s
' "${C_RED}Помилка: decimals має бути цілим (0-18)${C_RESET}"
        return 1
    fi

    # --- Конвертація ---
    AMOUNT="$(cybra_amount_to_wei "$AMOUNT_RAW" "$DECIMALS")"
    if [ -z "$AMOUNT" ] || [ "$AMOUNT" = "0" ]; then
        printf '%s
' "${C_RED}Помилка: невірний формат суми ($AMOUNT_RAW)${C_RESET}"
        return 1
    fi

    printf '
%s
' "${C_GREY}Конвертовано: $AMOUNT_RAW $TOKEN (decimals=$DECIMALS) → $AMOUNT wei${C_RESET}"
    printf '
'

    local cid
    cid="$(cybra_contract_create "$BUYER" "$SELLER" "$AMOUNT" "$TOKEN")"

    if [ -z "$cid" ]; then
        printf '%s
' "${C_RED}Помилка створення контракту${C_RESET}"
        return 1
    fi

    local cf="$(cybra_contract_path "$cid")"

    printf '%s
' "${C_GREEN}OK: контракт створено${C_RESET}"
    printf 'ID:              %s
' "$cid"
    printf 'TOKEN:           %s (decimals=%s)
' "$TOKEN" "$DECIMALS"
    printf 'AMOUNT:          %s wei (= %s токенів)
' "$AMOUNT" "$AMOUNT_RAW"
    printf '
'
    printf 'LICENSE_A (1%%):  %s wei
' "$(grep '^LICENSE_A_WEI=' "$cf" | cut -d= -f2)"
    printf 'LICENSE_B (1%%):  %s wei
' "$(grep '^LICENSE_B_WEI=' "$cf" | cut -d= -f2)"
    printf 'CREATION  (1%%):  %s wei
' "$(grep '^CREATION_FEE_WEI=' "$cf" | cut -d= -f2)"
    printf 'TOTAL (3%%):      %s wei
' "$(grep '^LICENSE_TOTAL_WEI=' "$cf" | cut -d= -f2)"
    printf 'NET SELLER:      %s wei
' "$(grep '^NET_WEI=' "$cf" | cut -d= -f2)"
    printf '
'
    printf 'Отримувачі ліцензій:
'
    printf '  A: %s
' "${LICENSE_A_RECIPIENT}"
    printf '  B: %s
' "${LICENSE_B_RECIPIENT}"
    printf '  C: %s

    # --- AUTO AI REVIEW ---
    if [ -f "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_local_ai.sh" ]; then
        printf "\n═══ AUTO AI REVIEW ═══\n"
        source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_local_ai.sh" 2>/dev/null
        local_ai_review_contract "$cid" 2>/dev/null || true
    fi

    # --- AUTO-AUTOSAVE ---
    if [ -x "$HOME/CYBRA/modules/module_35_cybra_guardian/bin/autosave.sh" ]; then
        source "$HOME/CYBRA/modules/module_35_cybra_guardian/bin/autosave.sh"
        as_save_all "$cid" 2>/dev/null || true
    fi

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

action_addr_add() {
    printf 'Назва (name):  '; read -r N
    printf 'Адреса (0x...): '; read -r A
    printf 'Тег [user]:     '; read -r T
    T="${T:-user}"
    bash "$HOME/CYBRA/modules/module_25_address_book/bin/address_book.sh" 2>/dev/null
    source "$HOME/CYBRA/modules/module_25_address_book/bin/address_book.sh"
    ab_add "$N" "$A" "$T"
    read -r _
}
action_addr_list()   { source "$HOME/CYBRA/modules/module_25_address_book/bin/address_book.sh"; ab_list; read -r _; }
action_addr_history(){ source "$HOME/CYBRA/modules/module_25_address_book/bin/address_book.sh"; ab_history; read -r _; }

action_qr() {
    source "$HOME/CYBRA/modules/module_26_qr_codes/bin/qr.sh"
    printf 'CONTRACT_ID: '; read -r C
    printf 'ROLE [BUYER]: '; read -r R
    R="${R:-BUYER}"
    qr_gen_link "$C" "$R"
    read -r _
}
action_tg_setup() {
    source "$HOME/CYBRA/modules/module_27_telegram_bot/bin/tg.sh"
    printf 'Bot Token:  '; read -r T
    printf 'Chat ID:    '; read -r C
    tg_set_token "$T"
    tg_set_chat "$C"
    echo "Налаштовано"
    read -r _
}
action_tg_test() { source "$HOME/CYBRA/modules/module_27_telegram_bot/bin/tg.sh"; tg_test; read -r _; }

action_wh_list() { source "$HOME/CYBRA/modules/module_32_webhook/bin/webhook.sh"; wh_list; read -r _; }
action_wh_add() {
    source "$HOME/CYBRA/modules/module_32_webhook/bin/webhook.sh"
    printf 'Name:   '; read -r N
    printf 'URL:    '; read -r U
    printf 'Events [*]: '; read -r E
    E="${E:-*}"
    wh_add "$N" "$U" "$E"
    read -r _
}

action_exp_csv()  { source "$HOME/CYBRA/modules/module_28_export/bin/export.sh"; exp_contracts_csv; read -r _; }
action_exp_ledger(){ source "$HOME/CYBRA/modules/module_28_export/bin/export.sh"; exp_ledger_csv; read -r _; }
action_exp_report(){
    source "$HOME/CYBRA/modules/module_28_export/bin/export.sh"
    printf 'CONTRACT_ID: '; read -r C
    exp_txt_report "$C"; read -r _
}

action_bk_local() { source "$HOME/CYBRA/modules/module_29_backup/bin/backup.sh"; bk_local; read -r _; }
action_bk_cloud() { source "$HOME/CYBRA/modules/module_29_backup/bin/backup.sh"; bk_cloud; read -r _; }

action_chains()   { source "$HOME/CYBRA/modules/module_30_multichain/bin/multichain.sh"; mc_list; read -r _; }
action_scan_tx() {
    source "$HOME/CYBRA/modules/module_30_multichain/bin/multichain.sh"
    printf 'CHAIN [BSC]: '; read -r C; C="${C:-BSC}"
    printf 'TX hash: '; read -r T
    mc_tx_link "$C" "$T"; read -r _
}

action_dp_open() {
    source "$HOME/CYBRA/modules/module_31_dispute_resolver/bin/dispute.sh"
    printf 'CONTRACT_ID: '; read -r C
    printf 'OPENED_BY (wallet): '; read -r B
    printf 'REASON: '; read -r R
    D="$(dp_open "$C" "$B" "$R")"
    echo "Opened: $D"; read -r _
}
action_dp_list() { source "$HOME/CYBRA/modules/module_31_dispute_resolver/bin/dispute.sh"; dp_list; read -r _; }
action_dp_vote() {
    source "$HOME/CYBRA/modules/module_31_dispute_resolver/bin/dispute.sh"
    printf 'DISPUTE_ID: '; read -r D
    printf 'VOTER [BUYER|SELLER|ARBITER]: '; read -r V
    printf 'VOTE [REFUND|RELEASE]: '; read -r O
    dp_vote "$D" "$V" "$O"; read -r _
}

action_audit_show() { source "$HOME/CYBRA/modules/module_33_audit_log/bin/audit.sh"; au_show; read -r _; }
action_audit_verify(){ source "$HOME/CYBRA/modules/module_33_audit_log/bin/audit.sh"; au_verify; read -r _; }

action_scan_photo() {
    source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh"
    sc_photo; read -r _
}
action_scan_ocr() {
    source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh"
    printf 'File path: '; read -r F
    sc_ocr "$F"; read -r _
}
action_scan_pdf() {
    source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh"
    printf 'PDF path: '; read -r F
    sc_pdf_to_text "$F"; read -r _
}
action_scan_full() {
    source "$HOME/CYBRA/modules/module_34_doc_scanner/bin/scanner.sh"
    sc_scan_pipeline; read -r _
}

# ═══ MODULE 35 — GUARDIAN ═══
GD_LIB="$HOME/CYBRA/modules/module_35_cybra_guardian/bin/guardian.sh"

action_gd_state()        { source "$GD_LIB"; gd_check_state; read -r _; }
action_gd_100()          {
    source "$GD_LIB"
    gd_check_state >/dev/null 2>&1
    local p="$(cat "$GUARD_EV/state_pct.txt" 2>/dev/null || echo 0)"
    if [ "$p" -eq 100 ]; then
        printf '%s✓ 100%% STATE%s\n' "${GR:-}" "${Z:-}"
    else
        printf '%s✗ %s%% — потрібно відновлення%s\n' "${RD:-}" "$p" "${Z:-}"
    fi
    read -r _
}
action_gd_register()     {
    source "$GD_LIB"
    printf "Ім'я / назва:      "; read -r N
    printf "ID номер (ЄДРПОУ/ІПН): "; read -r I
    printf 'Wallet (0x...):     '; read -r W
    printf 'Biometric (опц.):   '; read -r B
    gd_register "$N" "$I" "$W" "${B:-none}"
    read -r _
}
action_gd_show()         { source "$GD_LIB"; gd_show_identity; read -r _; }
action_gd_verify()       {
    source "$GD_LIB"
    printf "Ім'я:               "; read -r N
    printf 'ID номер:           '; read -r I
    printf 'Wallet:             '; read -r W
    printf 'Biometric (опц.):   '; read -r B
    gd_verify "$N" "$I" "$W" "${B:-none}"
    read -r _
}
action_gd_device()       { source "$GD_LIB"; gd_device_info; read -r _; }
action_gd_snapshot()     { source "$GD_LIB"; gd_recovery_snapshot; read -r _; }
action_gd_restore_git()  { source "$GD_LIB"; gd_recovery_from_git; read -r _; }
action_gd_restore_snap() { source "$GD_LIB"; gd_recovery_from_snapshot; read -r _; }
action_gd_auto()         { source "$GD_LIB"; gd_auto_recover; read -r _; }
action_gd_actions()      { tail -30 "$HOME/CYBRA/modules/module_35_cybra_guardian/evidence/actions.log" 2>/dev/null; read -r _; }
action_gd_log_verify()   { source "$GD_LIB"; gd_log_verify; read -r _; }


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
        40) action_ai_review ;;
        41) action_ai_parse_invoice ;;
        42) action_ai_generate_terms ;;
        43) action_ai_help_error ;;
        44) action_ai_ask ;;
        45) action_ai_taskbar ;;
        46) action_ai_executor_full ;;
        47) action_ai_executor_scan ;;
        48) action_ai_executor_apply ;;
        49) action_ai_executor_list ;;
        50) action_addr_add ;;
        51) action_addr_list ;;
        52) action_addr_history ;;
        53) action_qr ;;
        54) action_tg_setup ;;
        55) action_tg_test ;;
        56) action_wh_list ;;
        57) action_wh_add ;;
        58) action_exp_csv ;;
        59) action_exp_ledger ;;
        60) action_exp_report ;;
        61) action_bk_local ;;
        62) action_bk_cloud ;;
        63) action_chains ;;
        64) action_scan_tx ;;
        65) action_dp_open ;;
        66) action_dp_list ;;
        67) action_dp_vote ;;
        68) action_audit_show ;;
        69) action_audit_verify ;;
        70) action_scan_photo ;;
        71) action_scan_ocr ;;
        72) action_scan_pdf ;;
        73) action_scan_full ;;
        50) action_addr_add ;;
        51) action_addr_list ;;
        52) action_addr_history ;;
        53) action_qr ;;
        54) action_tg_setup ;;
        55) action_tg_test ;;
        56) action_wh_list ;;
        57) action_wh_add ;;
        58) action_exp_csv ;;
        59) action_exp_ledger ;;
        60) action_exp_report ;;
        61) action_bk_local ;;
        62) action_bk_cloud ;;
        63) action_chains ;;
        64) action_scan_tx ;;
        65) action_dp_open ;;
        66) action_dp_list ;;
        67) action_dp_vote ;;
        68) action_audit_show ;;
        69) action_audit_verify ;;
        70) action_scan_photo ;;
        71) action_scan_ocr ;;
        72) action_scan_pdf ;;
        73) action_scan_full ;;
        80) action_gd_state ;;
        81) action_gd_100 ;;
        82) action_gd_register ;;
        83) action_gd_show ;;
        84) action_gd_verify ;;
        85) action_gd_device ;;
        86) action_gd_snapshot ;;
        87) action_gd_restore_git ;;
        88) action_gd_restore_snap ;;
        89) action_gd_auto ;;
        90) action_gd_actions ;;
        91) action_gd_log_verify ;;
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

    printf '\n'
    printf '%s' "${C_GREY}Enter для продовження...${C_RESET}"
    read -r _
done
