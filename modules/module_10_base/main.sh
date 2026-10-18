#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 10: Підписати INVOICE
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_10.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 10. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Підписати INVOICE"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [10] Підписати INVOICE"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───

read -p "Токен: " T; read -p "Wallet: " W; echo "$T|$W" >> "$CYBRA/logs/signs.log"; echo "✅"

echo "════════════════════════════════════════════"
log "DONE: Підписати INVOICE"
read -r -p "Натисни Enter для виходу..." _
