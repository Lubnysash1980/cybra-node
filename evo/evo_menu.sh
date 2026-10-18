#!/data/data/com.termux/files/usr/bin/bash
EVO="$HOME/CYBRA/evo/evo_core.py"
clear
echo "════════════════════════════════════════════"
echo "  EVOLUTION CORE — ЯДРО РОЗВИТКУ"
echo "════════════════════════════════════════════"
echo ""
echo "  [1] Показати метрики (Metrics)"
echo "  [2] Запустити аналіз зараз (Force check)"
echo "  [3] Показати заплановані дії (Planned actions)"
echo "  [4] Показати логи (останні 20)"
echo "  [0] Назад"
echo ""
read -p "  Вибір: " c
case "$c" in
    1) python3 "$EVO" ;;
    2) python3 "$EVO"; read -r _ ;;
    3) python3 "$EVO" | grep "Planned" -A 20 ;;
    4) tail -20 "$HOME/CYBRA/evo/logs/evo.log"; read -r _ ;;
esac
