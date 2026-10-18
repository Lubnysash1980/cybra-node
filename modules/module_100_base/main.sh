#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 100: Node manager
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_100.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 100. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Node manager"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [100] Node manager"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
bash "$CYBRA/cybra_node.sh" check 2>&1 | tail -5

echo "════════════════════════════════════════════"
log "DONE: Node manager"
read -r -p "Натисни Enter для виходу..." _
