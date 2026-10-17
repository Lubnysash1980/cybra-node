#!/data/data/com.termux/files/usr/bin/bash
# parliament_auto_worker.sh — Фоновий IT-департамент
# Генерує по одному модулю кожні 30 секунд

CYBRA="$HOME/CYBRA"
ENGINE="$CYBRA/modules/module_121_parlament/bin/parliament_hidl_engine.py"
LOG="$CYBRA/logs/parliament_worker.log"

echo "=== Parliament Worker Started ===" >> "$LOG"

while true; do
    # Перевіряємо, чи є ще заглушки
    python3 "$ENGINE" >> "$LOG" 2>&1
    
    # Якщо є, генеруємо один модуль
    if grep -q "Потребують розробки (заглушки): [1-9]" "$LOG"; then
        python3 "$ENGINE" vote >> "$LOG" 2>&1
    else
        echo "[$(date)] Всі модулі реалізовано. Роботу завершено." >> "$LOG"
        break
    fi
    
    sleep 30
done
