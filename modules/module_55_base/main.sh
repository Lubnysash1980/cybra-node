#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 55: Telegram test
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_55.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 55. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Telegram test"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [55] Telegram test"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
source "$CYBRA/logs/tg.env" 2>/dev/null; echo "Token: $TG"

echo "════════════════════════════════════════════"
log "DONE: Telegram test"
read -r -p "Натисни Enter для виходу..." _
