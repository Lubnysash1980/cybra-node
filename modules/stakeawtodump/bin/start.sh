#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
LOG="$CYBRA/logs/stakeawtodump.log"

echo "[$(date '+%F %T')] START stakeawtodump" >> "$LOG"

# bg_dump
if [ -x "$CYBRA/bin/cybra_bg_dump_ctl.sh" ]; then
  "$CYBRA/bin/cybra_bg_dump_ctl.sh" start
fi

# autowatch
if [ -x "$CYBRA/bin/cybra_autowatch_ctl.sh" ]; then
  "$CYBRA/bin/cybra_autowatch_ctl.sh" start
fi

# autogit у pm2 (якщо god живий)
sleep 2
if pgrep -f "PM2.*God Daemon" >/dev/null && [ -x "$CYBRA/bin/wrappers/run_autogit.sh" ]; then
  pm2 describe cybra-autogit >/dev/null 2>&1 || \
    pm2 start "$CYBRA/bin/wrappers/run_autogit.sh" --name cybra-autogit \
      --interpreter bash --max-memory-restart 65M >/dev/null 2>&1
  pm2 save --force >/dev/null 2>&1
fi

echo "started"
