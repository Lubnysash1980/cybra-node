#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date '+%Y%m%d_%H%M%S')
OUT="$CYBRA/dumps/dump_$TS"
mkdir -p "$OUT"
pm2 jlist > "$OUT/pm2.json" 2>/dev/null
cp "$HOME/.pm2/dump.pm2" "$OUT/dump.pm2" 2>/dev/null
date '+%F %T' > "$OUT/timestamp"
echo "dump $TS"
ls -1dt "$CYBRA"/dumps/dump_*/ 2>/dev/null | tail -n +4 | xargs -r rm -rf
