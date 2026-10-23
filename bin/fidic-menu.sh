#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
ENGINE="$CYBRA/bin/fidic-engine.py"
FIDIC_DIR="$CYBRA/data/fidic"

while true; do
    clear
    echo "════════ 160. FIDIC КОНТРАКТИ ════════"
    echo "1) Створити новий контракт"
    echo "2) Перевірити/Валідувати контракт"
    echo "3) Список контрактів"
    echo "0) Назад"
    read -r -p "Вибір: " c
    case "$c" in
        1) read -r -p "ID контракту: " cid; python3 "$ENGINE" create "$cid"; read -r -p "Enter..." _ ;;
        2) read -r -p "ID контракту: " cid; python3 "$ENGINE" validate "$cid"; read -r -p "Enter..." _ ;;
        3) ls -la "$FIDIC_DIR" | grep ".json" || echo "Немає контрактів"; read -r -p "Enter..." _ ;;
        0) exit 0 ;;
    esac
done
