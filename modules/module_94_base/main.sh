#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 94: Останні архіви
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_94.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 94. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Останні архіви"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [94] Останні архіви"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
ls -t "$CYBRA"/*.tar.gz 2>/dev/null | head -3

echo "════════════════════════════════════════════"
log "DONE: Останні архіви"
read -r -p "Натисни Enter для виходу..." _
