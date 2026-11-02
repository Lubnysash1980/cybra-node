#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
while true; do
  python3 bin/cybra_resurrection_controller.py
  echo "[wrap:cybra-resurrection-ctrl] $(date +%H:%M:%S)"
  sleep 30
done
