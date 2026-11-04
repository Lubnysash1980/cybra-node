#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
SEL="${1:-}"
if [ -z "$SEL" ] || [ "$SEL" = "all" ]; then
  SRC=$(ls -1dt "$CYBRA"/dumps/dump_*/ 2>/dev/null | head -1)
else
  SRC="$SEL"
fi
[ -d "$SRC" ] || { echo "no dump found"; exit 1; }
if [ -f "$SRC/dump.pm2" ]; then
  cp "$SRC/dump.pm2" "$HOME/.pm2/dump.pm2"
  pm2 resurrect
fi
echo "restored from $SRC"
