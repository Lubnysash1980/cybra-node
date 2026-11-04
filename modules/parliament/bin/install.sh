#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
LOG="$CYBRA/logs/parliament.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "═══ PARLIAMENT INSTALL v0.2.0 ═══"

# 1. baseline
if [ ! -f "$MOD/state/baseline.json" ]; then
  "$MOD/bin/baseline.sh" >/dev/null
  log "  ✅ baseline created"
fi

# 2. Termux:Boot
if [ -d "$HOME/.termux/boot" ]; then
  cat > "$HOME/.termux/boot/cybra-parliament.sh" << 'B'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
sleep 30
~/CYBRA/modules/parliament/bin/parliament_ctl.sh start
B
  chmod +x "$HOME/.termux/boot/cybra-parliament.sh"
  log "  ✅ Termux:Boot hook"
fi

# 3. crontab fallback
if command -v crontab >/dev/null; then
  ( crontab -l 2>/dev/null | grep -v 'parliament_ctl'; \
    echo "@reboot sleep 35 && $MOD/bin/parliament_ctl.sh start" \
  ) | crontab -
  log "  ✅ crontab @reboot"
fi

# 4. start daemon now
"$MOD/bin/parliament_ctl.sh" start | tee -a "$LOG"
log "═══ DONE ═══"
