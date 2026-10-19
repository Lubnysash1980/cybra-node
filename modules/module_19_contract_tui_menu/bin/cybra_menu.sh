#!/data/data/com.termux/files/usr/bin/bash
# CYBRA CONTRACT TUI v1.2 — з пунктами 151/152
source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_tui_lib.sh" 2>/dev/null || true
source "$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_health.sh" 2>/dev/null || true

if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'; C_MAGENTA=$'\033[35m'; C_GREY=$'\033[90m'
else
    C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""
    C_YELLOW=""; C_BLUE=""; C_CYAN=""; C_MAGENTA=""; C_GREY=""
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
    printf '  🟢 [1]  Створити контракт\n'
    printf '  🟢 [2]  Список контрактів\n'
    printf '  🟢 [3]  Статус контракту\n'
    printf '  🟢 [4]  Згенерувати лінки\n'
    printf '  🟢 [5]  Підтвердити лінк\n'
    printf '  🟢 [6]  Debug\n'
    printf '  🟢 [7]  DUAL-LICENSE ledger\n'
    printf '  🟢 [8]  CREATION-LICENSE ledger\n'
    printf '  🟢 [9]  Hardening\n\n'

    printf '%s\n' "${C_CYAN}  ─── INVOICE ───${C_RESET}"
    printf '  🟢 [10] Підписати INVOICE\n'
    printf '  🟢 [11] Створити INVOICE\n'
    printf '  🟢 [12] Додати позицію\n'
    printf '  🟢 [13] Показати INVOICE\n'
    printf '  🟢 [14] Фіналізувати INVOICE\n\n'

    printf '%s\n' "${C_CYAN}  ─── REFUND ───${C_RESET}"
    printf '  🟢 [18] Рішення покупця\n'
    printf '  🟢 [19] Перевірити timeout\n'
    printf '  🟢 [20] Статус refund\n'
    printf '  🟢 [21] Додати умову\n\n'

    printf '%s\n' "${C_CYAN}  ─── ВАЛЮТИ ───${C_RESET}"
    printf '  🟢 [22] Курси\n'
    printf '  🟢 [23] Оновити курс\n'
    printf '  🟢 [24] Конвертер\n\n'

    printf '%s\n' "${C_CYAN}  ─── СИСТЕМА ───${C_RESET}"
    printf '  🟢 [30] Preflight\n'
    printf '  🟢 [31] Self-heal\n'
    printf '  🟢 [32] Dual-backend verify\n'
    printf '  🟢 [33] Ownership scan\n\n'

    printf '%s\n' "${C_MAGENTA}  ─── AI (офлайн) ───${C_RESET}"
    printf '  🟢 [40] AI Аналіз\n'
    printf '  🟢 [41] AI Парсинг рахунку\n'
    printf '  🟢 [42] AI Генерація умов\n'
    printf '  🟢 [43] AI Допомога\n'
    printf '  🟢 [44] AI Вільне питання\n'
    printf '  🟢 [45] AI Task Bar\n\n'

    printf '%s\n' "${C_MAGENTA}  ─── AI EVOLUTION ───${C_RESET}"
    printf '  🟢 [46] Executor — повний\n'
    printf '  🟢 [47] Executor — scan\n'
    printf '  🟢 [48] Executor — apply\n'
    printf '  🟢 [49] Executor — список\n\n'

    printf '%s\n' "${C_GREEN}  ─── ADDRESS BOOK ───${C_RESET}"
    printf '  🟢 [50] Додати адресу\n'
    printf '  🟢 [51] Список адрес\n'
    printf '  🟢 [52] Історія адрес\n\n'

    printf '%s\n' "${C_GREEN}  ─── INTEGRATIONS ───${C_RESET}"
    printf '  🟢 [53] QR-код\n'
    printf '  🟢 [54] Telegram setup\n'
    printf '  🟢 [55] Telegram test\n'
    printf '  🟢 [56] Webhook список\n'
    printf '  🟢 [57] Webhook додати\n\n'

    printf '%s\n' "${C_GREEN}  ─── EXPORT / BACKUP ───${C_RESET}"
    printf '  🟢 [58] CSV контракти\n'
    printf '  🟢 [59] CSV ledger\n'
    printf '  🟢 [60] TXT звіт\n'
    printf '  🟢 [61] Backup локальний\n'
    printf '  🟢 [62] Backup хмара\n\n'

    printf '%s\n' "${C_GREEN}  ─── MULTI-CHAIN ───${C_RESET}"
    printf '  🟢 [63] Список мереж\n'
    printf '  🟢 [64] Сканер-tx\n\n'

    printf '%s\n' "${C_RED}  ─── DISPUTE / AUDIT ───${C_RESET}"
    printf '  🟢 [65] Відкрити спір\n'
    printf '  🟢 [66] Список спорів\n'
    printf '  🟢 [67] Голосувати\n'
    printf '  🟢 [68] Audit log\n'
    printf '  🟢 [69] Audit перевірити\n\n'

    printf '%s\n' "${C_RED}  ─── DOCUMENT SCANNER ───${C_RESET}"
    printf '  🟢 [70] Сфотографувати\n'
    printf '  🟢 [71] OCR\n'
    printf '  🟢 [72] PDF → текст\n'
    printf '  🟢 [73] Pipeline\n\n'

    printf '%s\n' "${C_MAGENTA}  ─── РОЗШИРЕНІ ───${C_RESET}"
    printf '  🟢 [74] Пошук контракту\n'
    printf '  🟢 [75] Auto-fill\n'
    printf '  🟢 [76] AI прогін умов\n'
    printf '  🟢 [77] Перевірка платежів\n'
    printf '  🟢 [78] Додаткові умови\n'
    printf '  🟢 [79] Watchdog\n\n'

    printf '%s\n' "${C_RED}  ─── GUARDIAN (100%%) ───${C_RESET}"
    printf '  🟢 [80] Стан системи\n'
    printf '  🟢 [81] Перевірка 100%%\n'
    printf '  🟢 [82] Зареєструвати особу\n'
    printf '  🟢 [83] Показати особу\n'
    printf '  🟢 [84] Перевірити особу\n'
    printf '  🟢 [85] Пристрій\n'
    printf '  🟢 [86] Snapshot\n'
    printf '  🟢 [87] Відновити git\n'
    printf '  🟢 [88] Відновити snapshot\n'
    printf '  🟢 [89] AUTO-recovery\n'
    printf '  🟢 [90] Action log\n'
    printf '  🟢 [91] Log verify\n\n'

    printf '%s\n' "${C_RED}  ─── AUTOSAVE ───${C_RESET}"
    printf '  🟢 [92] Зберегти контракт\n'
    printf '  🟢 [93] Статус autosave\n'
    printf '  🟢 [94] Останні архіви\n'
    printf '  🟢 [95] Відновити контракт\n\n'

    printf '%s\n' "${C_RED}  ─── EVO CONTROLLERS ───${C_RESET}"
    printf '  🟢 [96] EVO7 (7 рівнів)\n'
    printf '  🟢 [97] EVO CONTROLLER\n'
    printf '  🟢 [98] Parawatch\n'
    printf '  🟢 [99] AUTOPATCH\n\n'

    printf '%s\n' "${C_MAGENTA}  ─── NODE / HASH / SYSTEM ───${C_RESET}"
    printf '  🟢 [100] Node manager\n'
    printf '  🟢 [101] Hash ecosystem\n'
    printf '  🟢 [102] Binmix daemon\n'
    printf '  🟢 [103] Metrics\n'
    printf '  🟢 [104] HTTP panel\n'
    printf '  🟢 [105] Schedule\n'
    printf '  🟢 [106] Cleanup\n'
    printf '  🟢 [107] Autopilot\n\n'

    printf '%s\n' "  ${C_BOLD}─── NODE/HASH ───${C_RESET}"
    printf '  🟢 [121] parlament\n'
    printf '  🟢 [120] ai guardian\n'
    printf '  🟢 [119] qr sign\n'
    printf '  🟢 [118] net health\n'
    printf '  🟢 [117] tx lookup\n'
    printf '  🟢 [116] gas monitor\n'
    printf '  🟢 [115] rpc bench\n'
    printf '  🟢 [114] autonode\n'
    printf '  🟢 [113] metamask batch\n'
    printf '  🟢 [112] metamask deeplink\n'
    printf '  🟢 [111] metamask settings\n'
    printf '  🟢 [110] metamask history\n'
    printf '  🟢 [109] metamask verify\n'
    printf '  🟢 [108] metamask sign\n\n'

    printf '%s\n' "  ${C_BOLD}─── METAMASK ───${C_RESET}"
    printf '  🟢 [124] timelock\n'
    printf '  🟢 [123] multisig\n'
    printf '  🟢 [122] contract validator\n\n'

    printf '%s\n' "  ${C_BOLD}─── ADVANCED ───${C_RESET}"
    printf '  🟢 [140] analytics\n'
    printf '  🟢 [139] reputation\n'
    printf '  🟢 [138] arbitration\n'
    printf '  🟢 [137] escrow\n'
    printf '  🟢 [136] templates\n'
    printf '  🟢 [135] walletconnect\n'
    printf '  🟢 [134] discord\n'
    printf '  🟢 [133] tokens\n'
    printf '  🟢 [132] compliance\n'
    printf '  🟢 [131] kyc\n'
    printf '  🟢 [130] test suite\n'
    printf '  🟢 [129] voice\n'
    printf '  🟢 [128] dashboard\n'
    printf '  🟢 [126] zk\n'
    printf '  🟢 [125] anchor\n\n'

    printf '%s\n' "  ${C_BOLD}─── ORCHESTRATOR ───${C_RESET}"
    printf '  🟢 [150] Custom Scripts\n'
    printf '  🟢 [149] Advanced Analytics\n'
    printf '  🟢 [148] Multisig UI\n'
    printf '  🟢 [147] Reputation v2\n'
    printf '  🟢 [146] Merkle Batching\n'
    printf '  🟢 [145] IPFS Pinning\n'
    printf '  🟢 [144] Bitcoin Lightning\n'
    printf '  🟢 [143] Email Notifications\n'
    printf '  🟢 [142] Invoice PDF Export\n'
    printf '  🟢 [141] Portfolio Tracker\n\n'

    printf '%s\n' "${C_GREEN}  ─── НОВІ (151/152) ───${C_RESET}"
    printf '  🟢 %s[151]%s Реклама (Ad Contract)\n' "$C_BOLD" "$C_RESET"
    printf '  🟢 %s[152]%s Відкат до чистої ноти EVO\n\n' "$C_BOLD" "$C_RESET"

    printf '  %s[0]%s  Вихід\n\n' "$C_BOLD" "$C_RESET"
}

while true; do
    print_header
    print_menu
    printf '  Вибір: '
    read -r CHOICE
    case "$CHOICE" in
        1) bash "$HOME/CYBRA/modules/module_1_base/main.sh" ;;
        2) bash "$HOME/CYBRA/modules/module_2_base/main.sh" ;;
        3) bash "$HOME/CYBRA/modules/module_3_base/main.sh" ;;
        4) bash "$HOME/CYBRA/modules/module_4_base/main.sh" ;;
        5) bash "$HOME/CYBRA/modules/module_5_base/main.sh" ;;
        6) bash "$HOME/CYBRA/modules/module_6_base/main.sh" ;;
        7) bash "$HOME/CYBRA/modules/module_7_base/main.sh" ;;
        8) bash "$HOME/CYBRA/modules/module_8_base/main.sh" ;;
        9) bash "$HOME/CYBRA/modules/module_9_base/main.sh" ;;
        10) bash "$HOME/CYBRA/modules/module_10_base/main.sh" ;;
        11) bash "$HOME/CYBRA/modules/module_11_base/main.sh" ;;
        12) bash "$HOME/CYBRA/modules/module_12_base/main.sh" ;;
        13) bash "$HOME/CYBRA/modules/module_13_base/main.sh" ;;
        14) bash "$HOME/CYBRA/modules/module_14_base/main.sh" ;;
        18) bash "$HOME/CYBRA/modules/module_18_base/main.sh" ;;
        19) bash "$HOME/CYBRA/modules/module_19_base/main.sh" ;;
        20) bash "$HOME/CYBRA/modules/module_20_base/main.sh" ;;
        21) bash "$HOME/CYBRA/modules/module_21_base/main.sh" ;;
        22) bash "$HOME/CYBRA/modules/module_22_base/main.sh" ;;
        23) bash "$HOME/CYBRA/modules/module_23_base/main.sh" ;;
        24) bash "$HOME/CYBRA/modules/module_24_base/main.sh" ;;
        30) bash "$HOME/CYBRA/modules/module_30_base/main.sh" ;;
        31) bash "$HOME/CYBRA/modules/module_31_base/main.sh" ;;
        32) bash "$HOME/CYBRA/modules/module_32_base/main.sh" ;;
        33) bash "$HOME/CYBRA/modules/module_33_base/main.sh" ;;
        40) bash "$HOME/CYBRA/modules/module_40_base/main.sh" ;;
        41) bash "$HOME/CYBRA/modules/module_41_base/main.sh" ;;
        42) bash "$HOME/CYBRA/modules/module_42_base/main.sh" ;;
        43) bash "$HOME/CYBRA/modules/module_43_base/main.sh" ;;
        44) bash "$HOME/CYBRA/modules/module_44_base/main.sh" ;;
        45) bash "$HOME/CYBRA/modules/module_45_base/main.sh" ;;
        46) bash "$HOME/CYBRA/modules/module_46_base/main.sh" ;;
        47) bash "$HOME/CYBRA/modules/module_47_base/main.sh" ;;
        48) bash "$HOME/CYBRA/modules/module_48_base/main.sh" ;;
        49) bash "$HOME/CYBRA/modules/module_49_base/main.sh" ;;
        50) bash "$HOME/CYBRA/modules/module_50_base/main.sh" ;;
        51) bash "$HOME/CYBRA/modules/module_51_base/main.sh" ;;
        52) bash "$HOME/CYBRA/modules/module_52_base/main.sh" ;;
        53) bash "$HOME/CYBRA/modules/module_53_base/main.sh" ;;
        54) bash "$HOME/CYBRA/modules/module_54_base/main.sh" ;;
        55) bash "$HOME/CYBRA/modules/module_55_base/main.sh" ;;
        56) bash "$HOME/CYBRA/modules/module_56_base/main.sh" ;;
        57) bash "$HOME/CYBRA/modules/module_57_base/main.sh" ;;
        58) bash "$HOME/CYBRA/modules/module_58_base/main.sh" ;;
        59) bash "$HOME/CYBRA/modules/module_59_base/main.sh" ;;
        60) bash "$HOME/CYBRA/modules/module_60_base/main.sh" ;;
        61) bash "$HOME/CYBRA/modules/module_61_base/main.sh" ;;
        62) bash "$HOME/CYBRA/modules/module_62_base/main.sh" ;;
        63) bash "$HOME/CYBRA/modules/module_63_base/main.sh" ;;
        64) bash "$HOME/CYBRA/modules/module_64_base/main.sh" ;;
        65) bash "$HOME/CYBRA/modules/module_65_base/main.sh" ;;
        66) bash "$HOME/CYBRA/modules/module_66_base/main.sh" ;;
        67) bash "$HOME/CYBRA/modules/module_67_base/main.sh" ;;
        68) bash "$HOME/CYBRA/modules/module_68_base/main.sh" ;;
        69) bash "$HOME/CYBRA/modules/module_69_base/main.sh" ;;
        70) bash "$HOME/CYBRA/modules/module_70_base/main.sh" ;;
        71) bash "$HOME/CYBRA/modules/module_71_base/main.sh" ;;
        72) bash "$HOME/CYBRA/modules/module_72_base/main.sh" ;;
        73) bash "$HOME/CYBRA/modules/module_73_base/main.sh" ;;
        74) bash "$HOME/CYBRA/modules/module_74_base/main.sh" ;;
        75) bash "$HOME/CYBRA/modules/module_75_base/main.sh" ;;
        76) bash "$HOME/CYBRA/modules/module_76_base/main.sh" ;;
        77) bash "$HOME/CYBRA/modules/module_77_base/main.sh" ;;
        78) bash "$HOME/CYBRA/modules/module_78_base/main.sh" ;;
        79) bash "$HOME/CYBRA/modules/module_79_base/main.sh" ;;
        80) bash "$HOME/CYBRA/modules/module_80_base/main.sh" ;;
        81) bash "$HOME/CYBRA/modules/module_81_base/main.sh" ;;
        82) bash "$HOME/CYBRA/modules/module_82_base/main.sh" ;;
        83) bash "$HOME/CYBRA/modules/module_83_base/main.sh" ;;
        84) bash "$HOME/CYBRA/modules/module_84_base/main.sh" ;;
        85) bash "$HOME/CYBRA/modules/module_85_base/main.sh" ;;
        86) bash "$HOME/CYBRA/modules/module_86_base/main.sh" ;;
        87) bash "$HOME/CYBRA/modules/module_87_base/main.sh" ;;
        88) bash "$HOME/CYBRA/modules/module_88_base/main.sh" ;;
        89) bash "$HOME/CYBRA/modules/module_89_base/main.sh" ;;
        90) bash "$HOME/CYBRA/modules/module_90_base/main.sh" ;;
        91) bash "$HOME/CYBRA/modules/module_91_base/main.sh" ;;
        92) bash "$HOME/CYBRA/modules/module_92_base/main.sh" ;;
        93) bash "$HOME/CYBRA/modules/module_93_base/main.sh" ;;
        94) bash "$HOME/CYBRA/modules/module_94_base/main.sh" ;;
        95) bash "$HOME/CYBRA/modules/module_95_base/main.sh" ;;
        96) bash "$HOME/CYBRA/bin/cybra_evo7" menu 2>/dev/null || echo "EVO7 недоступний"; read -r _ ;;
        97) bash "$HOME/CYBRA/bin/cybra_evo_ctl" run 2>/dev/null || echo "EVO CTL недоступний"; read -r _ ;;
        98) echo "Parawatch: перевірка"; read -r _ ;;
        99) bash "$HOME/CYBRA/bin/cybra_autopatch" 2>/dev/null || echo "AUTOPATCH недоступний"; read -r _ ;;
        100) bash "$HOME/CYBRA/cybra_node.sh" check 2>&1 | tail -5; read -r _ ;;
        101) echo "Hash ecosystem"; read -r _ ;;
        102) echo "Binmix"; read -r _ ;;
        103) free -h | head -2; read -r _ ;;
        104) echo "HTTP panel"; read -r _ ;;
        105) echo "Schedule"; read -r _ ;;
        106) echo "Cleanup"; read -r _ ;;
        107) echo "Autopilot"; read -r _ ;;
        108) python3 "$HOME/CYBRA/selfgen/selfgen_core.py" check 2>/dev/null; read -r _ ;;
        109) bash "$HOME/CYBRA/brain/brain_menu.sh" 2>/dev/null; read -r _ ;;
        110) bash "$HOME/CYBRA/evo/evo_menu.sh" 2>/dev/null; read -r _ ;;
        111) bash "$HOME/CYBRA/lifecycle/lifecycle_menu.sh" 2>/dev/null; read -r _ ;;
        112) python3 "$HOME/CYBRA/lifecycle/autoresolver.py" resolve 2>/dev/null; read -r _ ;;
        113|114|115|116|117|118|119|120|121|122|123|124|125|126|127|128|129|130|131|132|133|134|135|136|137|138|139|140|141|142|143|144|145|146|147|148|149|150)
            bash "$HOME/CYBRA/modules/module_${CHOICE}_base/main.sh" 2>/dev/null || echo "Модуль $CHOICE"; read -r _ ;;
        151) bash "$HOME/CYBRA/modules/module_151_ad_contract/main.sh" ;;
        152) bash "$HOME/CYBRA/modules/module_152_rollback_evo/main.sh" ;;
        0|q|Q|exit|quit)
            printf "%s\n" "${C_GREEN}До побачення.${C_RESET}"
            exit 0
            ;;
        *)
            printf "%s\n" "${C_RED}Невідома опція.${C_RESET}"
            ;;
    esac
done
