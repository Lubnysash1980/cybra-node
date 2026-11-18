#!/data/data/com.termux/files/usr/bin/bash
cd ~/CYBRA
. barmenu/lib/colors.sh

while true; do
    clear
    title "═══ 🏛️ PARLIAMENT / НЕЙРО ═══"
    echo "1) Відправити нову задачу в Парламент"
    echo "2) Перевірити чергу задач (Redis)"
    echo "3) Перевірити логи Нейро (cybra-brain)"
    echo "4) Перезапустити Нейро"
    echo "0) Назад"
    echo ""
    read -p "Обери: " C

    case "$C" in
        1)
            echo ""
            read -p "Текст задачі: " TEXT
            if [ -n "$TEXT" ]; then
                cybra-it task "$TEXT" && ok "✅ Задача відправлена в Парламент!"
            fi
            ;;
        2)
            echo ""
            N=$(redis-cli LLEN cybra:ai:tasks:block_inbox 2>/dev/null || echo 0)
            info "Задач у черзі: $N"
            if [ "$N" -gt 0 ]; then
                echo "Останні задачі:"
                redis-cli LRANGE cybra:ai:tasks:block_inbox 0 2 2>/dev/null | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line)
        print('  -', d.get('text', d.get('payload', {}).get('text', '???'))[:80])
    except: pass
"
            fi
            ;;
        3)
            echo ""
            pm2 logs cybra-brain --lines 15 --nostream
            ;;
        4)
            echo ""
            pm2 restart cybra-brain && ok "✅ Нейро перезапущено!"
            ;;
        0|"")
            return 0
            ;;
    esac
    echo ""
    read -p "Enter для продовження..."
done
