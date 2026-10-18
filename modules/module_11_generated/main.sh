#!/data/data/com.termux/files/usr/bin/bash
echo "═══ Створити INVOICE ═══"
read -p "Сума (грн): " s
read -p "ПДВ (20%): " v
echo "Сума без ПДВ: $(echo "$s - $v" | bc)"
read -r _