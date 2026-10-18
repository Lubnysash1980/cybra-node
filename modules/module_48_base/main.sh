#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 48: Executor apply
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_48.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 48. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Executor apply"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [48] Executor apply"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
bash "$CYBRA/ai/cybra_ai_executor.sh" apply 2>&1 | tail -5

echo "════════════════════════════════════════════"
log "DONE: Executor apply"
read -r -p "Натисни Enter для виходу..." _
