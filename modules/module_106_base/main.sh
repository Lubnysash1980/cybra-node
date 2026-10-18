#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 106: Cleanup
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_106.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 106. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Cleanup"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [106] Cleanup"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
bash "$CYBRA/bin/cybra_cleanup" 2>/dev/null; echo "✅"

echo "════════════════════════════════════════════"
log "DONE: Cleanup"
read -r -p "Натисни Enter для виходу..." _
