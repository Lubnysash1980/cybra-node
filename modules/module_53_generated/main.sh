#!/data/data/com.termux/files/usr/bin/bash
echo "═══ QR-код ═══"
read -p "Введіть текст для QR: " q
if command -v qrencode >/dev/null; then
    qrencode -t ANSIUTF8 "$q"
else
    echo "⚠ qrencode не встановлено."
fi
read -r _