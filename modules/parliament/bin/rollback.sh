#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
LOG="$CYBRA/logs/parliament.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "═══ ROLLBACK ═══"
[ -x "$CYBRA/bin/cybra_autowatch_ctl.sh" ] && "$CYBRA/bin/cybra_autowatch_ctl.sh" stop 2>/dev/null
[ -x "$CYBRA/bin/cybra_bg_dump_ctl.sh" ]   && "$CYBRA/bin/cybra_bg_dump_ctl.sh"   stop 2>/dev/null
[ -x "$CYBRA/bin/cybra_autorestore.sh" ]   && "$CYBRA/bin/cybra_autorestore.sh" >> "$LOG" 2>&1
[ -x "$CYBRA/bin/cybra_autowatch_ctl.sh" ] && "$CYBRA/bin/cybra_autowatch_ctl.sh" start
sleep 3
log "rollback complete"
