#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 61: Backup локальний
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_61.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 61. Лог: $LOG"; read -r _; exit 1' ERR

log "START: Backup локальний"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [61] Backup локальний"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
tar -czf "$CYBRA/backup_$(date +%s).tar.gz" "$CYBRA/config" 2>/dev/null; echo "✅"

echo "════════════════════════════════════════════"
log "DONE: Backup локальний"
read -r -p "Натисни Enter для виходу..." _
