#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 13: Показати INVOICE
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_13.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 13. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Показати INVOICE"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [13] Показати INVOICE"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───

read -p "ID: " C; cat "$CYBRA/modules/module_19_contract_tui_menu/contracts/$C.json" 2>/dev/null; cat "$CYBRA/logs/items_$C.log" 2>/dev/null

echo "════════════════════════════════════════════"
log "DONE: Показати INVOICE"
read -r -p "Натисни Enter для виходу..." _
