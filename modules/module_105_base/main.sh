#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 105: Schedule
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_105.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 105. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Schedule"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [105] Schedule"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
bash "$CYBRA/bin/cybra_schedule" status 2>/dev/null || echo "⚠"

echo "════════════════════════════════════════════"
log "DONE: Schedule"
read -r -p "Натисни Enter для виходу..." _
