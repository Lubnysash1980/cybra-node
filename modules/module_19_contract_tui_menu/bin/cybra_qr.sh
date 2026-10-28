#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
OUT_DIR="$CYBRA/data/qr"
mkdir -p "$OUT_DIR"

if ! command -v qrencode >/dev/null 2>&1; then
    echo "⚠ qrencode не встановлено. Встанови: pkg install qrencode"
    exit 1
fi

payload="${1:-}"
[ -z "$payload" ] && read -rp "Текст/URL/IBAN: " payload
[ -z "$payload" ] && exit 1

out="$OUT_DIR/qr_$(date -u +%Y%m%dT%H%M%SZ).png"
qrencode -o "$out" -s 8 -m 2 "$payload" && echo "✅ $out"
