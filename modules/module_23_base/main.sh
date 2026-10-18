#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 23: Оновити курс
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_23.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 23. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Оновити курс"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [23] Оновити курс"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
read -p "K: " K; read -p "V: " V; echo "$K=$V" >> "$CYBRA/logs/rates.log"

echo "════════════════════════════════════════════"
log "DONE: Оновити курс"
read -r -p "Натисни Enter для виходу..." _
