#!/data/data/com.termux/files/usr/bin/bash
# module_262: peer_ble (peer) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-scan}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="peer_ble"
MODULE_CAT="peer"

case "$ACTION" in
  scan)
    if ! command -v termux-bluetooth-scan >/dev/null 2>&1 && ! command -v termux-bluetooth-connection >/dev/null 2>&1; then
      echo "❌ termux-api без BT підтримки"
      echo "   BLE-advertising потребує Flutter/native (Android BLE APIs)"
      echo "   Тут тільки: увімкни BT + спробуй 'scan' через bluetoothctl"
    fi
    # Termux fallback: bluetoothctl (якщо pkg install bluez)
    if command -v bluetoothctl >/dev/null 2>&1; then
      timeout 10 bluetoothctl scan on 2>/dev/null | head -5
      echo "✅ BT scan (10s)"
    else
      echo "❌ no BT stack. Options:"
      echo "   a) pkg install bluez"
      echo "   b) BLE native — Flutter (real path)"
    fi
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  BLE peer discovery: NEEDS Flutter/native"
    echo "  Termux: bluetoothctl (basic scan)"
    echo "  hint: $0 scan"
    ;;
esac
