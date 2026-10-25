#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 6: Debug
# СТАТУС: EXTENDED (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_6.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 6. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Debug"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [6] Debug"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───

echo "HOME=$HOME"; pm2 list | head -5

echo "════════════════════════════════════════════"
log "DONE: Debug"
read -r -p "Натисни Enter для виходу..." _
