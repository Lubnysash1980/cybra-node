#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 97: EVO CTL
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_97.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 97. Лог: $LOG"; read -r _; exit 1' ERR

log "START: EVO CTL"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [97] EVO CTL"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
bash "$CYBRA/bin/cybra_evo_ctl" run 2>/dev/null || echo "⚠"

echo "════════════════════════════════════════════"
log "DONE: EVO CTL"
read -r -p "Натисни Enter для виходу..." _
