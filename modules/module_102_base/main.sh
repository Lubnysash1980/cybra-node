#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 102: Binmix daemon
CYBRA="$HOME/CYBRA"
BINMIX="$CYBRA/bin/cybra_binmix"
if [ ! -x "$BINMIX" ]; then
    echo "❌ cybra_binmix не знайдено або не виконується"
    read -r _
    exit 1
fi
"$BINMIX" status 2>/dev/null || "$BINMIX" 2>/dev/null || echo "⚠ binmix не відповідає"
read -r _
