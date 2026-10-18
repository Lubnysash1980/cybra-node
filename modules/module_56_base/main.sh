#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 56: Webhook list
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_56.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 56. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Webhook list"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [56] Webhook list"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
cat "$CYBRA/logs/webhooks.log" 2>/dev/null

echo "════════════════════════════════════════════"
log "DONE: Webhook list"
read -r -p "Натисни Enter для виходу..." _
