#!/data/data/com.termux/files/usr/bin/bash
source "$HOME/CYBRA/lib/parliament_api.sh"
echo "═══ FINAL CHECK ═══"
echo "level:     $(parliament_level)/7"
echo "ready:     $(parliament_ready && echo YES || echo NO)"
echo "status:    $(parliament_status)"
echo "binmix:    $(~/CYBRA/bin/cybra_binmix status 2>/dev/null | grep -oE 'RUNNING|STOPPED')"
echo "RAM:       $(free -m | awk '/Mem:/{printf "%d%%",$3/$2*100}')"
echo "snapshots: $(ls -1 ~/CYBRA/snapshots/parliament_*.tar.gz 2>/dev/null | wc -l)"
echo "API:       $([ -f ~/CYBRA/lib/parliament_api.sh ] && echo OK || echo MISSING)"
echo "─── PM2 ───"
pm2 list 2>/dev/null | grep -E 'redis|parliament|tracker|runtime|binmix'
