#!/data/data/com.termux/files/usr/bin/bash
# cybra_autowatch_install.sh — одноразово: створити, налаштувати, запустити.
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1

echo "═══ AUTOWATCH INSTALL ═══"

# 1. перевірка залежностей
for f in bin/cybra_bg_dump.sh bin/cybra_bg_dump_ctl.sh bin/cybra_autogit.sh \
         bin/cybra_dump.sh bin/cybra_dump_components.sh bin/cybra_autorestore.sh \
         bin/cybra_autowatch.sh bin/cybra_autowatch_ctl.sh; do
  if [ -x "$CYBRA/$f" ]; then echo "  ✅ $f"
  else echo "  ❌ missing/not-exec: $f"; MISSING=1; fi
done

# 2. створити wrapper autogit якщо нема
if [ ! -x "$CYBRA/bin/wrappers/run_autogit.sh" ]; then
  mkdir -p "$CYBRA/bin/wrappers"
  cat > "$CYBRA/bin/wrappers/run_autogit.sh" << 'W'
#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
exec bin/cybra_autogit.sh --daemon 300
W
  chmod +x "$CYBRA/bin/wrappers/run_autogit.sh"
  echo "  + created bin/wrappers/run_autogit.sh"
fi

# 3. карантин (порожній)
touch "$CYBRA/.keeper-quarantine"

# 4. autostart при reboot (одна строчка, БЕЗ періодичних cron-перезапусків)
if command -v crontab >/dev/null; then
  ( crontab -l 2>/dev/null | grep -v "cybra_autowatch_ctl"; \
    echo "@reboot sleep 25 && $CYBRA/bin/cybra_autowatch_ctl.sh start" \
  ) | crontab -
  echo "  ✅ @reboot → autowatch"
else
  echo "  ⚠ crontab недоступний. Постав: pkg install cronie; crond"
fi

# 5. стоп старі nohup (щоб не було двох)
[ -f "$CYBRA/.cache/bg_dump.pid" ] && kill "$(cat "$CYBRA/.cache/bg_dump.pid")" 2>/dev/null
pkill -f "cybra_autowatch.sh" 2>/dev/null
sleep 1

# 6. запустити обидва
echo ""
echo "── start bg_dump ──"
"$CYBRA/bin/cybra_bg_dump_ctl.sh" start
echo ""
echo "── start autowatch ──"
"$CYBRA/bin/cybra_autowatch_ctl.sh" start

sleep 3
echo ""
echo "═══ STATUS ═══"
"$CYBRA/bin/cybra_autowatch_ctl.sh" status
echo ""
echo "  ✓ install done"
echo "  керування: cybra_autowatch_ctl.sh {start|stop|status|restart|log}"
echo "  логи:      logs/autowatch.log, logs/bg_dump.log"
