#!/data/data/com.termux/files/usr/bin/bash
# CYBRA CONTRACT TUI v1.2
source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh" 2>/dev/null || true
source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_health.sh" 2>/dev/null || true

if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
    C_CYAN=$'\033[36m'; C_MAGENTA=$'\033[35m'; C_GREY=$'\033[90m'
else
    C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_CYAN=""; C_MAGENTA=""; C_GREY=""
fi

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
    printf '%s\n' "${C_BOLD}${C_CYAN}              CYBRA CONTRACT MANAGER — TUI v1.2${C_RESET}"
    printf '%s\n' "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════${C_RESET}"
    printf '  🟢 READY  │  BSC(56)  │  1%%+1%%+1%% license\n'
    printf '  %s modules  │  %s contracts  │  %s links\n' "$mods" "$cons" "$links"
    printf '%s\n' "  ${C_GREY}🕐 $now${C_RESET}"
    printf '%s\n' "${C_GREY}────────────────────────────────────────────────────────────${C_RESET}"
    printf '\n'
}

print_menu() {
    printf '%s\n' "${C_BOLD}  ─── ОСНОВНЕ ───${C_RESET}"

    printf '%s\n' "${C_CYAN}  ─── INVOICE ───${C_RESET}"

    printf '%s\n' "${C_CYAN}  ─── REFUND ───${C_RESET}"

    printf '%s\n' "${C_CYAN}  ─── ВАЛЮТИ ───${C_RESET}"

    printf '%s\n' "${C_CYAN}  ─── СИСТЕМА ───${C_RESET}"

    printf '%s\n' "${C_MAGENTA}  ─── AI (офлайн) ───${C_RESET}"

    printf '%s\n' "${C_MAGENTA}  ─── AI EVOLUTION ───${C_RESET}"

    printf '%s\n' "${C_GREEN}  ─── ADDRESS BOOK ───${C_RESET}"

    printf '%s\n' "${C_GREEN}  ─── INTEGRATIONS ───${C_RESET}"

    printf '%s\n' "${C_GREEN}  ─── EXPORT / BACKUP ───${C_RESET}"

    printf '%s\n' "${C_GREEN}  ─── MULTI-CHAIN ───${C_RESET}"

    printf '%s\n' "${C_RED}  ─── DISPUTE / AUDIT ───${C_RESET}"

    printf '%s\n' "${C_RED}  ─── DOCUMENT SCANNER ───${C_RESET}"

    printf '%s\n' "${C_MAGENTA}  ─── РОЗШИРЕНІ ───${C_RESET}"

    printf '%s\n' "${C_RED}  ─── GUARDIAN (100%%) ───${C_RESET}"

    printf '%s\n' "${C_RED}  ─── AUTOSAVE ───${C_RESET}"

    printf '%s\n' "${C_RED}  ─── EVO CONTROLLERS ───${C_RESET}"

    printf '%s\n' "${C_MAGENTA}  ─── NODE / HASH / SYSTEM ───${C_RESET}"

    printf '%s\n' "  ${C_BOLD}─── NODE/HASH ───${C_RESET}"

    printf '%s\n' "  ${C_BOLD}─── METAMASK ───${C_RESET}"

    printf '%s\n' "  ${C_BOLD}─── ADVANCED ───${C_RESET}"

    printf '%s\n' "  ${C_BOLD}─── ORCHESTRATOR ───${C_RESET}"
    printf '  🟢 [150] Custom Scripts\n'
    printf '  🟢 [149] Advanced Analytics\n'

    printf '%s\n' "${C_GREEN}  ─── НОВІ (151/152) ───${C_RESET}"
    printf '  🟢 %s[151]%s Реклама (Ad Contract)\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[152]%s Відкат до чистої ноти EVO\n\n' "$C_BOLD" "$C_RESET"

    printf '  🟢 [154] Менеджер посилань (Тунель)\n'
    printf '  🟢 [160] FIDIC Контракти\n'
    printf '\n'
    printf '  %s[0]%s  Вихід\n\n' "$C_BOLD" "$C_RESET"
}

while true; do
    print_header
    print_menu
    printf '  Вибір: '
    read -r CHOICE
    case "$CHOICE" in
        1) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_1_base/main.sh" ;;
        2) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_2_base/main.sh" ;;
        3) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_3_base/main.sh" ;;
        4) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_4_base/main.sh" ;;
        5) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_5_base/main.sh" ;;
        6) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_6_base/main.sh" ;;
        7) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_7_base/main.sh" ;;
        8) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_8_base/main.sh" ;;
        9) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_9_base/main.sh" ;;
        10|11|12|13|14) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh" ;;
        18|19|20|21) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh" ;;
        22|23|24) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh" ;;
        30|31|32|33) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh" ;;
        40|41|42|43|44|45|46|47|48|49) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh" ;;
        50|51|52|53|54|55|56|57) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh" ;;
        58|59|60|61|62|63|64|65|66|67|68|69|70|71|72|73) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh" ;;
        74|75|76|77|78|79|80|81|82|83|84|85|86|87|88|89|90|91|92|93|94|95|96|97|98|99) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh" ;;
        149) bash "$HOME/CYBRA/modules/module_149_analytics/main.sh" ;;
            ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh" ;;
        151) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_151_ad_contract/main.sh" ;;
        152) ~/CYBRA/controllers/module-controller.sh "$HOME/CYBRA/modules/module_152_rollback_evo/main.sh" ;;
        154) bash "$HOME/CYBRA/bin/cybra-link-manager.sh" ;;
        160) bash "$HOME/CYBRA/bin/fidic-menu.sh" ;;
        154) bash "$HOME/CYBRA/bin/cybra-link-manager.sh" ;;
        160) bash "$HOME/CYBRA/bin/fidic-menu.sh" ;;
        0|q|Q|exit|quit) printf "%s\n" "${C_GREEN}До побачення.${C_RESET}"; exit 0 ;;
        *) printf "%s\n" "${C_RED}Невідома опція.${C_RESET}" ;;
    esac
done
