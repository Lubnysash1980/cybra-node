#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 104: HTTP panel
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_104.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 104. Лог: $LOG"; read -r _; exit 1' ERR

log "START: HTTP panel"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [104] HTTP panel"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
bash "$CYBRA/bin/cybra_http" status 2>/dev/null || echo "⚠"

echo "════════════════════════════════════════════"
log "DONE: HTTP panel"
read -r -p "Натисни Enter для виходу..." _
