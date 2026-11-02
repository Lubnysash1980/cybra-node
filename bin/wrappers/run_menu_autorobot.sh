#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
while true; do
  python3 bin/cybra_menu_autorobot.py cycle
  echo "[wrap:menu-autorobot] $(date +%H:%M:%S)"
  sleep 15
done
