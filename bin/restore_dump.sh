#!/data/data/com.termux/files/usr/bin/bash
set -u
D="${1:-$HOME/CYBRA/dumps/latest}"
[ -d "$D" ] || D=$(ls -d $HOME/CYBRA/dumps/dump_*/ 2>/dev/null | tail -1)
[ -d "$D" ] || { echo "no dump found"; exit 1; }
echo "restore from: $D"

# 1. pm2
pgrep -f "PM2.*God Daemon" | xargs -r kill -9
sleep 2
cp "$D/pm2.dump" ~/.pm2/dump.pm2
pm2 resurrect
sleep 3
pm2 save --force

# 2. state
cp "$D/state/"*.json ~/CYBRA/state/ 2>/dev/null
[ -f "$D/state/cybra.level" ] && cp "$D/state/cybra.level" ~/CYBRA/state/

# 3. report
echo ""
echo "═══ RESTORED ═══"
pm2 list
echo ""
echo "online: $(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length')/$(pm2 jlist 2>/dev/null | jq 'length')"
