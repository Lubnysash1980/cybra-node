#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 95: Відновити контракт
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_95.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 95. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Відновити контракт"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [95] Відновити контракт"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
cd "$CYBRA" && git reset --hard HEAD -q && echo "✅"

echo "════════════════════════════════════════════"
log "DONE: Відновити контракт"
read -r -p "Натисни Enter для виходу..." _
