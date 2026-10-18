#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 98: Parawatch
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_98.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 98. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Parawatch"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [98] Parawatch"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
bash "$CYBRA/bin/cybra_parawatch" status 2>/dev/null || echo "⚠"

echo "════════════════════════════════════════════"
log "DONE: Parawatch"
read -r -p "Натисни Enter для виходу..." _
