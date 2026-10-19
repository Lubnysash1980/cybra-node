#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
BINMIX="$CYBRA/bin/cybra_binmix"
if [ ! -x "$BINMIX" ]; then
    echo "❌ cybra_binmix не знайдено"
    read -r _
    exit 1
fi
"$BINMIX" status
read -r _
