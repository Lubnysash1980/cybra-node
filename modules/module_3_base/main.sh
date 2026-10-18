#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 3: Статус контракту
# СТАТУС: EXTENDED (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_3.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 3. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Статус контракту"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [3] Статус контракту"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───

read -p "ID: " C; cat "$CYBRA/modules/module_19_contract_tui_menu/contracts/$C.json" 2>/dev/null || echo "❌ Немає"

echo "════════════════════════════════════════════"
log "DONE: Статус контракту"
read -r -p "Натисни Enter для виходу..." _
