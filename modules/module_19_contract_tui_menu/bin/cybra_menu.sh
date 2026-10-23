#!/data/data/com.termux/files/usr/bin/bash
# CYBRA CONTRACT TUI v3.1 - AI INTEGRATED

if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_GREEN=$'\033[32m'; C_CYAN=$'\033[36m'; C_MAGENTA=$'\033[35m'
else
    C_RESET=""; C_BOLD=""; C_GREEN=""; C_CYAN=""; C_MAGENTA=""
fi

print_menu() {
    clear 2>/dev/null || printf '\033[2J\033[H'
    echo "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════${C_RESET}"
    echo "${C_BOLD}${C_CYAN}              CYBRA CONTRACT MANAGER — v3.1${C_RESET}"
    echo "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════${C_RESET}"
    echo ""
    echo "${C_BOLD}${C_GREEN}  ─── ГОЛОВНІ ІНСТРУМЕНТИ ───${C_RESET}"
    echo "  🟢 [149] Аналітика системи"
    echo "  🟢 [151] Реклама (Ad Contract)"
    echo "  🟢 [152] Відкат до чистої ноти EVO"
    echo "  🟢 [154] Менеджер посилань (Тунель)"
    echo "  🟢 [160] FIDIC Контракти"
    echo ""
    echo "${C_MAGENTA}  ─── БАЗОВІ МОДУЛІ (AI) ───${C_RESET}"
    echo "  🟢 [1-148] Запустити конкретний модуль (введіть цифру)"
    echo ""
    echo "  ${C_BOLD}[0]  Вихід${C_RESET}"
    echo ""
}

while true; do
    print_menu
    printf '  Вибір: '
    read -r CHOICE

    case "$CHOICE" in
        149) bash "$HOME/CYBRA/modules/module_149_analytics/main.sh" ;;
        151) bash "$HOME/CYBRA/modules/module_151_ad_contract/main.sh" ;;
        152) bash "$HOME/CYBRA/modules/module_152_rollback_evo/main.sh" ;;
        154) bash "$HOME/CYBRA/bin/cybra-link-manager.sh" ;;
        160) bash "$HOME/CYBRA/bin/fidic-menu.sh" ;;
        0|q|Q|exit|quit) echo "До побачення."; exit 0 ;;
        *)
            if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le 148 ]; then
                bash "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh"
            else
                echo "⚠ Невідома опція: $CHOICE"
                sleep 1
            fi
            ;;
    esac
done
