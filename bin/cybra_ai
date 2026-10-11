#!/data/data/com.termux/files/usr/bin/bash
# CYBRA AI TASK BAR — локальний офлайн AI (без API)

ROOT="$HOME/CYBRA"
AIDIR="$ROOT/ai"
MOD="$ROOT/modules/module_19_contract_tui_menu"

# ─── Load local AI ───
if [ -f "$AIDIR/cybra_local_ai.sh" ]; then
    source "$AIDIR/cybra_local_ai.sh"
else
    echo "ERROR: cybra_local_ai.sh not found"
    echo "Run: cybra_self_heal"
    exit 1
fi

# ─── Кольори ───
if [ -t 1 ]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'
    B=$'\033[1m'; C=$'\033[36m'; Z=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; C=""; Z=""
fi

header() {
    clear 2>/dev/null || printf '\033[2J\033[H'
    printf '%s%s════════════════════════════════════════════════════════════%s\n' "$B" "$C" "$Z"
    printf '%s%s              CYBRA AI TASK BAR (LOCAL)%s\n' "$B" "$C" "$Z"
    printf '%s%s════════════════════════════════════════════════════════════%s\n' "$B" "$C" "$Z"
    printf '  Engine: %sLOCAL (офлайн, без API)%s\n' "$G" "$Z"
    printf '  Mode:   %sinteractive%s\n' "$C" "$Z"
    printf '\n'
}

menu() {
    printf '  %s[1]%s Аналіз контракту\n' "$B" "$Z"
    printf '  %s[2]%s Парсинг рахунку з тексту\n' "$B" "$Z"
    printf '  %s[3]%s Генерувати умови угоди\n' "$B" "$Z"
    printf '  %s[4]%s Допомога при помилці\n' "$B" "$Z"
    printf '  %s[5]%s Вільне питання\n' "$B" "$Z"
    printf '\n'
    printf '  %s[0]%s Вихід\n' "$B" "$Z"
    printf '\n  Вибір: '
}

list_contracts() {
    printf '  %sКонтракти (останні 10):%s\n' "$C" "$Z"
    ls -t "$MOD/contracts"/*.env 2>/dev/null | head -10 | while read f; do
        [ -f "$f" ] || continue
        cid="$(basename "$f" .env)"
        stage="$(grep -m1 '^STAGE=' "$f" 2>/dev/null | cut -d= -f2-)"
        printf '    %s [%s]\n' "$cid" "${stage:-?}"
    done
    printf '\n'
}

# ═══ Main loop ═══
while true; do
    header
    menu
    read -r CHOICE

    printf '\n'

    case "$CHOICE" in
        1)
            list_contracts
            printf 'CONTRACT_ID: '; read -r cid
            [ -n "$cid" ] && local_ai_review_contract "$cid"
            ;;
        2)
            local_ai_parse_invoice
            ;;
        3)
            list_contracts
            printf 'CONTRACT_ID: '; read -r cid
            [ -n "$cid" ] && local_ai_generate_terms "$cid"
            ;;
        4)
            printf 'Помилка (встав текст): '
            read -r err
            [ -n "$err" ] && local_ai_help_error "$err"
            ;;
        5)
            printf 'Питання: '
            read -r q
            [ -n "$q" ] && local_ai_answer "$q"
            ;;
        0|q|Q|exit|quit)
            printf '%sДо побачення%s\n' "$G" "$Z"
            exit 0
            ;;
        *)
            printf '%sНевідома опція%s\n' "$R" "$Z"
            ;;
    esac

    printf '\n%sEnter для продовження...%s' "$Y" "$Z"
    read -r _
done
