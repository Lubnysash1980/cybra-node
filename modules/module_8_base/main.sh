#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 8: CREATION-LICENSE
# СТАТУС: EXTENDED (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_8.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 8. Лог: $LOG"; read -r _; exit 1' ERR

log "START: CREATION-LICENSE"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [8] CREATION-LICENSE"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───

tail -10 "$CYBRA/modules/module_19_contract_tui_menu/evidence/creation_license_ledger.txt" 2>/dev/null || echo "Порожньо"

echo "════════════════════════════════════════════"
log "DONE: CREATION-LICENSE"
read -r -p "Натисни Enter для виходу..." _
