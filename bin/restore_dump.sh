#!/data/data/com.termux/files/usr/bin/bash
# restore_dump.sh — відновлення ТІЛЬКИ 100% дампів. --force для інших.
set -u
FORCE=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --force|-f) FORCE=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
D="${ARGS[0]:-$HOME/CYBRA/dumps/latest}"
[ -d "$D" ] || D=$(ls -d "$HOME"/CYBRA/dumps/dump_*/ 2>/dev/null | tail -1)
[ -d "$D" ] || { echo "no dump found"; exit 1; }

echo "── policy check ──"
if ! "$HOME/CYBRA/bin/cybra_dump_policy.sh" "$D"; then
  if [ "$FORCE" -eq 0 ]; then
    echo ""
    echo "❌ dump NOT 100% — restore blocked (use --force to override)"
    exit 2
  else
    echo "⚠ --force: restoring non-100% dump"
  fi
else
  echo "✅ dump is 100% portable"
fi

echo ""
echo "restore from: $D"

pgrep -f "PM2.*God Daemon" | xargs -r kill -9
sleep 2
cp "$D/pm2.dump" ~/.pm2/dump.pm2
pm2 resurrect
sleep 3
pm2 save --force

cp "$D/state/"*.json ~/CYBRA/state/ 2>/dev/null
[ -f "$D/state/cybra.level" ] && cp "$D/state/cybra.level" ~/CYBRA/state/

echo ""
echo "═══ RESTORED ═══"
pm2 list
echo ""
echo "online: $(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length')/$(pm2 jlist 2>/dev/null | jq 'length')"
