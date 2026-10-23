#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
cd "$CYBRA" || exit

C_GREEN="\033[1;32m"
C_CYAN="\033[1;36m"
C_YELLOW="\033[1;33m"
C_RESET="\033[0m"

clear 2>/dev/null
echo -e "${C_CYAN}══════════════════════════════════════════════════════${C_RESET}"
echo -e "${C_CYAN}             CYBRA SYSTEM DASHBOARD                   ${C_RESET}"
echo -e "${C_CYAN}══════════════════════════════════════════════════════${C_RESET}"
echo ""

# 1. Статус процесів
echo -e "${C_YELLOW}─── 1. ПРОЦЕСИ (PM2) ───${C_RESET}"
pm2 ls | grep -E "name|cybra"
echo ""

# 2. Стан еволюції (100% Lock)
echo -e "${C_YELLOW}─── 2. ЕВОЛЮЦІЙНИЙ СТАН (100% LOCK) ───${C_RESET}"
if [ -f "$CYBRA/state/evo_safe_state.json" ]; then
    BASELINE=$(python3 -c "import json; print(json.load(open('$CYBRA/state/evo_safe_state.json'))['baseline'])" 2>/dev/null)
    echo -e "Базова відмітка: ${C_GREEN}${BASELINE}%${C_RESET}"
else
    echo "Файл стану не знайдено."
fi
echo ""

# 3. Контракти (Реклама + FIDIC)
echo -e "${C_YELLOW}─── 3. КОНТРАКТИ ───${C_RESET}"
ADS_COUNT=$(sqlite3 "$CYBRA/data/ads.db" "SELECT COUNT(*) FROM ads;" 2>/dev/null || echo "0")
FIDIC_COUNT=$(ls "$CYBRA/data/fidic/"*.json 2>/dev/null | wc -l)
echo -e "Реклама (SQLite): ${C_GREEN}$ADS_COUNT${C_RESET} шт."
echo -e "FIDIC (JSON):     ${C_GREEN}$FIDIC_COUNT${C_RESET} шт."
echo ""

# 4. Git (Нода)
echo -e "${C_YELLOW}─── 4. СИНХРОНІЗАЦІЯ З НОДОЮ (GIT) ───${C_RESET}"
LAST_COMMIT=$(git log -1 --format="%h %s" 2>/dev/null)
LAST_TAG=$(git describe --tags --always 2>/dev/null)
echo "Останній коміт: $LAST_COMMIT"
echo -e "Поточний реліз: ${C_GREEN}$LAST_TAG${C_RESET}"
echo ""

# 5. Останні події Моноліту
echo -e "${C_YELLOW}─── 5. ОСТАННІ ПОДІЇ МОНОЛІТУ ───${C_RESET}"
tail -n 4 "$CYBRA/logs/monolith.log" 2>/dev/null || echo "Логи порожні."
echo ""
echo -e "${C_CYAN}══════════════════════════════════════════════════════${C_RESET}"
