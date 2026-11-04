#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
LOG="$CYBRA/logs/autodopomoga.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

log "═══ AUTODOPOMOGA INSTALL ═══"
mkdir -p "$MOD/state" "$CYBRA/.cache" "$CYBRA/logs"

# syntax gate
for f in "$MOD/bin/"*.sh; do
    bash -n "$f" && log "  ✅ $(basename "$f")" || { log "  ❌ $f"; exit 1; }
done
jq . "$MOD/contracts.json" >/dev/null && log "  ✅ contracts.json"

# Termux:Boot
if [ -d "$HOME/.termux/boot" ]; then
    cat > "$HOME/.termux/boot/cybra-autodopomoga.sh" << 'B'
#!/data/data/com.termux/files/usr/bin/bash
termux-wake-lock
sleep 25
~/CYBRA/modules/autodopomoga/bin/ctl.sh start
B
    chmod +x "$HOME/.termux/boot/cybra-autodopomoga.sh"
    log "  ✅ Termux:Boot hook"
fi

# crontab fallback — idempotent start кожні 5 хв (pidfile перевірка всередині)
if command -v crontab >/dev/null; then
    ( crontab -l 2>/dev/null | grep -v 'autodopomoga/bin/ctl'; \
      echo "@reboot sleep 30 && $MOD/bin/ctl.sh start"; \
      echo "*/5 * * * * $MOD/bin/ctl.sh start >/dev/null 2>&1" \
    ) | crontab -
    log "  ✅ crontab: @reboot + */5 min self-heal"
fi

# start now
"$MOD/bin/ctl.sh" start | tee -a "$LOG"
sleep 2
"$MOD/bin/ctl.sh" status | tee -a "$LOG"
log "═══ DONE ═══"
