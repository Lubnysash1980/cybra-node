#!/data/data/com.termux/files/usr/bin/bash
# module_071 — smart-stub v1 (real system data)
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null
echo "════════ module_071 ════════"
echo ""
echo "── git ──"
git --no-pager log -1 --format='  %h %s (%cr)' 2>/dev/null | head -1
echo "  files changed: $(git status --porcelain 2>/dev/null | wc -l)"
echo ""
echo "── redis ──"
redis-cli ping 2>/dev/null | sed 's/^/  /' || echo "  DOWN"
redis-cli dbsize 2>/dev/null | sed 's/^/  keys: /'
echo ""
echo "── system ──"
free -m 2>/dev/null | awk '/Mem:/{printf "  RAM: %d/%d MB (%d%%)\n", $3, $2, $3/$2*100}'
df -h /data 2>/dev/null | awk 'NR==2{printf "  disk: %s used of %s (%s)\n", $3, $2, $5}'
echo ""
echo "── pm2 core ──"
pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    online=sum(1 for p in d if p['pm2_env']['status']=='online')
    print(f'  online: {online}/{len(d)}')
except: print('  pm2 unavailable')
" 2>/dev/null || echo "  pm2 unavailable"
echo ""
echo "── module dir ──"
ls -la "$(dirname "$0")" 2>/dev/null | awk 'NR>1 && NR<8{print "  "$9" "$5"B"}'
echo ""
echo "── log (last 3) ──"
tail -3 logs/module_071*.log 2>/dev/null | sed 's/^/  /' || echo "  (no log)"
echo ""
read -r -p "Enter..." _
