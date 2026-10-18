#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 12: Додати позицію
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_12.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 12. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Додати позицію"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [12] Додати позицію"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───

read -p "ID: " C; read -p "Назва: " N; read -p "Ціна: " P; echo "$N|$P" >> "$CYBRA/logs/items_$C.log"; echo "✅"

echo "════════════════════════════════════════════"
log "DONE: Додати позицію"
read -r -p "Натисни Enter для виходу..." _
