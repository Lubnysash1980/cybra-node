#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
BINMIX="$CYBRA/bin/cybra_binmix"
[ -x "$BINMIX" ] || { echo "❌ binmix не знайдено"; read -r _; exit 1; }
"$BINMIX" status
read -r _
