#!/data/data/com.termux/files/usr/bin/bash
source "$HOME/CYBRA/lib/parliament_api.sh"
echo "═══ COMPLEX TEST ═══"

echo "[1] level: $(parliament_level)/7"
echo "[2] ready: $(parliament_ready && echo YES || echo NO)"
echo "[3] redis: $(redis-cli ping)"
echo "[4] queue: $(redis-cli llen cybra:parliament:queue)"

echo "[5] надсилаю 5 тестових задач"
for i in 1 2 3 4 5; do
  parliament_submit "{\"id\":\"test_$i\",\"type\":\"smoke\"}" >/dev/null
done

echo "[6] чекаю"
parliament_wait 120 0

echo "[7] останні 3 результати:"
parliament_results 3

echo "[8] binmix: $(~/CYBRA/bin/cybra_binmix status 2>/dev/null | grep -oE 'RUNNING|STOPPED')"
echo "[9] RAM: $(free -m | awk '/Mem:/{printf "%d%%",$3/$2*100}')"
echo "[10] PM2:"
pm2 list 2>/dev/null | grep -E 'redis|parliament|tracker|binmix'
