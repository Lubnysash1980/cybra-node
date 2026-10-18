#!/data/data/com.termux/files/usr/bin/bash
PM="$HOME/CYBRA/parliament_core/priority_manager.py"
clear
echo "════════════════════════════════════════════"
echo "  CYBER PARLIAMENT — PRIORITY MANAGER"
echo "════════════════════════════════════════════"
echo ""
echo "  [1] Show registry (winners per action)"
echo "  [2] Show conflicts"
echo "  [3] IT suggestions"
echo "  [4] Force scan"
echo "  [0] Back"
echo ""
read -p "Choice: " c
case "$c" in
    1) python3 "$PM" show; read -r _ ;;
    2) python3 "$PM" conflicts; read -r _ ;;
    3) python3 "$PM" suggest; read -r _ ;;
    4) python3 "$PM" scan; read -r _ ;;
esac
