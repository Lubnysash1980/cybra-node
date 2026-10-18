#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 86: Snapshot
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_86.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 86. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Snapshot"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [86] Snapshot"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
~/.termux/boot/start-cybra.sh 2>/dev/null; echo "✅"

echo "════════════════════════════════════════════"
log "DONE: Snapshot"
read -r -p "Натисни Enter для виходу..." _
