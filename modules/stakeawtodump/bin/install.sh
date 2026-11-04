#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
STATE="$MOD/state"; mkdir -p "$STATE"
LOG="$CYBRA/logs/stakeawtodump.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
log "═══ STAKEAWTODUMP INSTALL ═══"
for c in pm2 jq bash redis-cli; do command -v "$c" >/dev/null && log "✅ $c" || log "❌ $c"; done
for f in bin/cybra_bg_dump.sh bin/cybra_bg_dump_ctl.sh bin/cybra_autowatch.sh bin/cybra_autowatch_ctl.sh bin/cybra_autogit.sh bin/cybra_dump.sh bin/cybra_dump_components.sh bin/wrappers/run_autogit.sh; do
  [ -x "$CYBRA/$f" ] && log "✅ $f" || log "❌ $f"
done
touch "$CYBRA/.keeper-quarantine"
cat > "$STATE/install.json" << J
{ "ts": $(date +%s), "iso": "$(date -Iseconds)", "cybra": "$CYBRA", "module": "$MOD", "license": "MIT", "version": "1.0.0" }
J
log "═══ DONE ═══"
