#!/data/data/com.termux/files/usr/bin/bash
echo "═══ CYBRA STATE ═══"
echo "level:          $(cat ~/CYBRA/state/cybra.level 2>/dev/null || echo ?)/7"
echo "redis:          $(redis-cli ping 2>/dev/null || echo DOWN)"
echo "queue:          $(redis-cli llen cybra:parliament:queue 2>/dev/null)"
echo "results:        $(redis-cli llen cybra:parliament:results 2>/dev/null)"
echo "failed:         $(redis-cli llen cybra:parliament:failed 2>/dev/null)"
echo "executors:      $(ps aux | grep -c '[p]arliament_executor')"
echo "binmix:         $(~/CYBRA/bin/cybra_binmix status 2>/dev/null | grep -oE 'RUNNING|STOPPED' || echo unknown)"
echo "RAM:            $(free -m | awk '/Mem:/{printf "%d%%",$3/$2*100}')"
echo "─── PM2 ───"
pm2 list 2>/dev/null | grep -E 'redis|parliament|runtime|tracker|binmix'
echo "─── STATS ───"
redis-cli hgetall cybra:complexity:stats 2>/dev/null | paste - - | sort
