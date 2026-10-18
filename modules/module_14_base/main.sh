#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 14: Фіналізувати INVOICE
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_14.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 14. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Фіналізувати INVOICE"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [14] Фіналізувати INVOICE"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───

read -p "ID: " C; sed -i "s/draft/complete/" "$CYBRA/modules/module_19_contract_tui_menu/contracts/$C.json" 2>/dev/null; echo "✅"

echo "════════════════════════════════════════════"
log "DONE: Фіналізувати INVOICE"
read -r -p "Натисни Enter для виходу..." _
