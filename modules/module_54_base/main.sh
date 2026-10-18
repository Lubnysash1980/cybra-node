#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 54: Telegram setup
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_54.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 54. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Telegram setup"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [54] Telegram setup"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
read -p "Token: " T; echo "TG=$T" > "$CYBRA/logs/tg.env"

echo "════════════════════════════════════════════"
log "DONE: Telegram setup"
read -r -p "Натисни Enter для виходу..." _
