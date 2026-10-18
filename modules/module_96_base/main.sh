#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 96: EVO7
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_96.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 96. Лог: $LOG"; read -r _; exit 1' ERR

log "START: EVO7"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [96] EVO7"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
bash "$CYBRA/bin/cybra_evo7" menu 2>/dev/null || echo "⚠"

echo "════════════════════════════════════════════"
log "DONE: EVO7"
read -r -p "Натисни Enter для виходу..." _
