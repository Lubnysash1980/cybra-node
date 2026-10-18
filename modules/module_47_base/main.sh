#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 47: Executor scan
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_47.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 47. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Executor scan"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [47] Executor scan"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
bash "$CYBRA/ai/cybra_ai_executor.sh" scan 2>&1 | tail -5

echo "════════════════════════════════════════════"
log "DONE: Executor scan"
read -r -p "Натисни Enter для виходу..." _
