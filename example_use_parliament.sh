#!/data/data/com.termux/files/usr/bin/bash
source "$HOME/CYBRA/lib/parliament_api.sh"

echo "1. Статус:"
parliament_status

echo "2. Готовність:"
parliament_wait_ready 30

echo "3. Надсилаю 3 задачі:"
for i in 1 2 3; do
  parliament_submit "{\"id\":\"demo_$i\",\"task\":\"test\"}"
done

echo "4. Чекаю, поки парламент обробить:"
parliament_wait 60 0

echo "5. Останні 5 результатів:"
parliament_results 5
