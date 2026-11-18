#!/data/data/com.termux/files/usr/bin/bash
. "$(dirname "$0")/colors.sh"
MOD="${1:-}"
state=$(pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin); m=[x for x in d if x['name']=='$MOD']
    if not m: print('missing 0'); sys.exit()
    env=m[0]['pm2_env']
    print(env['status'], env.get('restart_time',0))
except: print('missing 0')
")
online=$(echo "$state" | cut -d' ' -f1)
restarts=$(echo "$state" | cut -d' ' -f2)
errcount=0
if [ "$online" = "online" ]; then
    errcount=$(pm2 logs "$MOD" --lines 50 --nostream 2>/dev/null | grep -ciE "❌|error|failed" || echo 0)
fi
if [ "$online" = "online" ] && [ "$restarts" -lt 3 ] && [ "$errcount" -lt 2 ]; then
    echo -e "${GREEN}● GREEN${NC}   ${MOD}  (r=${restarts})"; echo "GREEN"
elif [ "$online" = "online" ]; then
    echo -e "${YELLOW}● YELLOW${NC}  ${MOD}  (r=${restarts}, err=${errcount})"; echo "YELLOW"
else
    echo -e "${RED}● RED${NC}     ${MOD}  (${online})"; echo "RED"
fi
