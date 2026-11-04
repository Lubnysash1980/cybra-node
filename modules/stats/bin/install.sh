#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
LOG="$CYBRA/logs/stats.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "═══ STATS INSTALL ═══"
mkdir -p "$MOD/state" "$CYBRA/.cache" "$CYBRA/logs"

for f in "$MOD/bin/"*.sh; do
    bash -n "$f" && log "  ✅ $(basename "$f")" || { log "  ❌ $f"; exit 1; }
done
jq . "$MOD/rules.json" >/dev/null && log "  ✅ rules.json"

# boot hooks
if [ -d "$HOME/.termux/boot" ]; then
    cat > "$HOME/.termux/boot/cybra-stats.sh" << 'B'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
sleep 40
~/CYBRA/modules/stats/bin/ctl.sh start
B
    chmod +x "$HOME/.termux/boot/cybra-stats.sh"
    log "  ✅ Termux:Boot"
fi
if command -v crontab >/dev/null; then
    ( crontab -l 2>/dev/null | grep -v 'stats/bin/ctl'; \
      echo "@reboot sleep 40 && $MOD/bin/ctl.sh start"; \
      echo "*/5 * * * * $MOD/bin/ctl.sh start >/dev/null 2>&1" \
    ) | crontab -
    log "  ✅ crontab"
fi

"$MOD/bin/ctl.sh" start | tee -a "$LOG"
sleep 2
log "═══ DONE ═══"
