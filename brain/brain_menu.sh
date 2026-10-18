#!/data/data/com.termux/files/usr/bin/bash
BRAIN="$HOME/CYBRA/brain/brain_core.py"
clear
echo "════════════════════════════════════════════"
echo "  SYSTEM BRAIN — ЦЕНТРАЛЬНИЙ ОРКЕСТРАТОР"
echo "════════════════════════════════════════════"
echo ""
echo "  [1] Показати поточний стан (Analysis)"
echo "  [2] Показати план дій (What brain wants to do)"
echo "  [3] Запустити аналіз зараз (Force check)"
echo "  [4] Показати логи (останні 20)"
echo "  [0] Назад"
echo ""
read -p "  Вибір: " c
case "$c" in
    1) python3 "$BRAIN" ;;
    2) python3 "$BRAIN" | grep "Planned" -A 20 ;;
    3) python3 "$BRAIN"; read -r _ ;;
    4) tail -20 "$HOME/CYBRA/brain/logs/brain.log"; read -r _ ;;
esac
