#!/data/data/com.termux/files/usr/bin/bash
# CYBRA CONTRACT MANAGER — REAL LOGIC EDITION

source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh" 2>/dev/null || true
source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_health.sh" 2>/dev/null || true

if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
    C_CYAN=$'\033[36m'; C_MAGENTA=$'\033[35m'
else
    C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_CYAN=""; C_MAGENTA=""
fi

# === РЕАЛЬНІ ФУНКЦІЇ (Логіка з оригіналу) ===
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
        printf '  %s\n' "$cid"; n=$((n+1))
    done
    printf '\nВсього: %s\n' "$n"
    read -r _
}

action_show_status() {
    printf 'CONTRACT_ID: '; read -r C
    if [ -f "$CYBRA_CONTRACTS/$C.env" ]; then
        cat "$CYBRA_CONTRACTS/$C.env" | sed 's/^/  /'
    else
        echo "❌ Не знайдено: $C"
    fi
    read -r _
}

action_create_invoice() {
    printf '%s\n' "${C_BOLD}--- Створити INVOICE ---${C_RESET}"
    printf 'ПІБ покупця:     '; read -r BN
    printf 'ІПН:             '; read -r BI
    printf 'Сума (wei):      '; read -r AM
    printf 'Token:           '; read -r TK
    CID="$(cybra_contract_create_invoice "$BN" "$BI" "$AM" "$TK")" 2>/dev/null
    printf '%s\n' "${C_GREEN}OK: $CID${C_RESET}"
    read -r _
}

action_ai_ask() {
    printf 'Питання: '; read -r Q
    source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_local_ai.sh" 2>/dev/null
    local_ai_answer "$Q" 2>/dev/null || echo "AI офлайн."
    read -r _
}

action_debug() {
    echo "CYBRA_HOME=$HOME/CYBRA"
    pm2 ls
    read -r _
}

# === ВІДОБРАЖЕННЯ МЕНЮ ===
print_menu() {
    clear 2>/dev/null || printf '\033[2J\033[H'
    echo "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════${C_RESET}"
    echo "${C_BOLD}${C_CYAN}              CYBRA CONTRACT MANAGER — REAL TUI${C_RESET}"
    echo "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════${C_RESET}"
    echo ""
    echo "  🟢 [1]  Створити контракт"
    echo "  🟢 [2]  Список контрактів"
    echo "  🟢 [3]  Статус контракту"
    echo "  🟢 [4]  Створити INVOICE"
    echo "  🟢 [5]  Debug (PM2)"
    echo "  🟢 [6]  AI Аналіз"
    echo ""
    echo "  ${C_MAGENTA}─── ВСІ МОДУЛІ (1-160) ───${C_RESET}"
    echo "  (Введіть номер від 1 до 160 для запуску відповідного модуля)"
    echo ""
    echo "  🧬 [161] EvoSafe (3%)   🧬 [162] Tracker 100%   🧬 [163] 7 Levels"
    echo "  🛠️  [999] АВТО-РЕМОНТ"
    echo "  [0] Вихід"
    echo ""
}

# === ГОЛОВНИЙ ЦИКЛ ===
while true; do
    print_menu
    printf '  Вибір: '
    read -r CHOICE

    case "$CHOICE" in
        1) action_create_contract ;;
        2) action_list_contracts ;;
        3) action_show_status ;;
        4) action_create_invoice ;;
        5) action_debug ;;
        6) action_ai_ask ;;
        161) python3 "$HOME/CYBRA/bin/cybra-evo-safe.py" ;;
        162) python3 "$HOME/CYBRA/bin/cybra-absolute-state.py" ;;
        163) python3 "$HOME/CYBRA/bin/cybra-7levels-pm2.py" ;;
        999) python3 "$HOME/CYBRA/bin/cybra-auto-repair.py"; read -r -p "Enter..." _ ;;
        0|q|Q) echo "До побачення."; exit 0 ;;
        *)
            if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le 160 ]; then
                bash "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh"
            else
                echo "⚠ Невідома опція"
                sleep 1
            fi
            ;;
    esac
done
