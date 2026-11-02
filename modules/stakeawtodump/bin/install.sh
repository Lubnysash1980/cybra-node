#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
STATE="$MOD/state"; mkdir -p "$STATE"
LOG="$CYBRA/logs/stakeawtodump.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "═══ STAKEAWTODUMP INSTALL ═══"

# 1. залежності
for c in pm2 jq bash redis-cli; do
  command -v "$c" >/dev/null && log "  ✅ $c" || log "  ❌ $c missing"
done

# 2. перевірити скрипти бази
for f in bin/cybra_bg_dump.sh bin/cybra_bg_dump_ctl.sh bin/cybra_autowatch.sh \
         bin/cybra_autowatch_ctl.sh bin/cybra_autogit.sh \
         bin/cybra_dump.sh bin/cybra_dump_components.sh \
         bin/wrappers/run_autogit.sh; do
  [ -x "$CYBRA/$f" ] && log "  ✅ $f" || log "  ❌ $f"
done

# 3. карантин-файл
touch "$CYBRA/.keeper-quarantine"

# 4. wrapper autogit (якщо відсутній)
if [ ! -x "$CYBRA/bin/wrappers/run_autogit.sh" ]; then
  mkdir -p "$CYBRA/bin/wrappers"
  cat > "$CYBRA/bin/wrappers/run_autogit.sh" << 'W'
#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
exec bin/cybra_autogit.sh --daemon 300
W
  chmod +x "$CYBRA/bin/wrappers/run_autogit.sh"
fi

# 5. Termux:Boot hook (якщо є ~/.termux/boot)
if [ -d "$HOME/.termux/boot" ]; then
  cat > "$HOME/.termux/boot/cybra-stakeawtodump.sh" << 'B'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
sleep 20
~/CYBRA/modules/stakeawtodump/bin/start.sh
B
  chmod +x "$HOME/.termux/boot/cybra-stakeawtodump.sh"
  log "  ✅ Termux:Boot hook"
fi

# 6. cron @reboot (fallback, якщо є crontab)
if command -v crontab >/dev/null; then
  ( crontab -l 2>/dev/null | grep -v "stakeawtodump"; \
    echo "@reboot sleep 25 && $MOD/bin/start.sh" \
  ) | crontab -
  log "  ✅ crontab @reboot"
fi

# 7. інсталяційний маркер
cat > "$STATE/install.json" << J
{
  "ts": $(date +%s),
  "iso": "$(date -Iseconds)",
  "cybra": "$CYBRA",
  "module": "$MOD",
  "license": "MIT",
  "version": "1.0.0"
}
J
log "install marker written"
log "═══ DONE ═══"
