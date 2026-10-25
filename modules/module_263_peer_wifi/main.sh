#!/data/data/com.termux/files/usr/bin/bash
# module_263: peer_wifi (peer) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-scan}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="peer_wifi"
MODULE_CAT="peer"

case "$ACTION" in
  scan)
    # Wi-Fi Direct (P2P) — needs native. Termux: scan networks only.
    if command -v termux-wifi-scaninfo >/dev/null 2>&1; then
      termux-wifi-scaninfo 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    for n in d[:10]:
        print(f\"  SSID: {n.get('SSID','?')}  BSSID: {n.get('BSSID','?')}  RSSI: {n.get('RSSI',0)}\")
except Exception as e: print('parse error:', e)
"
    else
      echo "❌ pkg install termux-api + app"
    fi
    ;;
  p2p)
    echo "⚠️ Wi-Fi Direct (P2P) — Flutter plugin only"
    echo "   native: android.net.wifi.p2p.*"
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  Wi-Fi scan: $0 scan"
    echo "  Wi-Fi P2P: needs Flutter"
    ;;
esac
