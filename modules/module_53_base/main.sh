#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 53: QR-код
# СТАТУС: BASE (готовий до апгрейду Парламентом)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_53.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# ─── АВТО-ФІКС ПРИ ПОМИЛКАХ (EVO TRAP) ───
trap 'log "ERR line $LINENO"; echo "❌ Помилка в модулі 53. Лог: $LOG"; read -r _; exit 1' ERR

log "START: QR-код"
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [53] QR-код"
echo "════════════════════════════════════════════"

# ─── БАЗОВА ЛОГІКА ───
read -p "Текст: " T; command -v qrencode >/dev/null && qrencode -t ANSIUTF8 "$T" || echo "⚠ qrencode немає"

echo "════════════════════════════════════════════"
log "DONE: QR-код"
read -r -p "Натисни Enter для виходу..." _
