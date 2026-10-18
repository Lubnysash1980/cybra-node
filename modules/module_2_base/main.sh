#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 2: Список контрактів
# СТАТУС: EXTENDED (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_2.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 2. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Список контрактів"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [2] Список контрактів"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───

ls "$CYBRA/modules/module_19_contract_tui_menu/contracts/"*.json 2>/dev/null | wc -l | xargs echo "Всього контрактів:"

echo "════════════════════════════════════════════"
log "DONE: Список контрактів"
read -r -p "Натисни Enter для виходу..." _
