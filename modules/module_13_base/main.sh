#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 13: Показати INVOICE (без trap, щоб не було фальшивих помилок)

CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/module_13.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

source "$CYBRA/lib/cybra_invoice_lib.sh" 2>/dev/null
export CYBRA_INVOICE_DIR="$CYBRA/modules/module_19_contract_tui_menu/contracts"

echo "════════════════════════════════════════════"
echo "  [13] ПОКАЗАТИ INVOICE"
echo "════════════════════════════════════════════"
read -p "ID: " ID

if [ -z "$ID" ]; then
    echo "❌ ID не вказано"
    read -r _
    exit 1
fi

cybra_invoice_show "$ID"
log "SHOW: $ID"

read -r -p "Натисни Enter..." _
exit 0
