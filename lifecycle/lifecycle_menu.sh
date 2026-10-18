#!/data/data/com.termux/files/usr/bin/bash
LC="$HOME/CYBRA/lifecycle/lifecycle_manager.py"
clear
echo "════════════════════════════════════════════"
echo "  LIFECYCLE MANAGER — ГНУЧКА ПЕРЕВІРКА"
echo "════════════════════════════════════════════"
echo ""
echo "  [1] Показати стан (show)"
echo "  [2] Пересканувати (scan)"
echo "  [3] Перевести в розробку (mark)"
echo "  [0] Назад"
echo ""
read -p "  Вибір: " c
case "$c" in
    1) python3 "$LC" show; read -r _ ;;
    2) python3 "$LC" scan; read -r _ ;;
    3) 
        read -p "Модуль: " M
        read -p "Причина: " R
        python3 "$LC" mark "$M" "$R"
        read -r _ ;;
esac
