#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 46: Executor full
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_46.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 46. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Executor full"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [46] Executor full"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
bash "$CYBRA/ai/cybra_ai_executor.sh" full 2>&1 | tail -5

echo "════════════════════════════════════════════"
log "DONE: Executor full"
read -r -p "Натисни Enter для виходу..." _
