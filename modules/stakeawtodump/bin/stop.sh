#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
[ -x "$CYBRA/bin/cybra_autowatch_ctl.sh" ] && "$CYBRA/bin/cybra_autowatch_ctl.sh" stop
[ -x "$CYBRA/bin/cybra_bg_dump_ctl.sh" ] && "$CYBRA/bin/cybra_bg_dump_ctl.sh" stop
pm2 delete cybra-autogit 2>/dev/null
pm2 save --force >/dev/null 2>&1
echo "stopped"
