#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
echo "[wrap:autorestore] start"
while true; do
  bin/cybra_autorestore.sh
  sleep 300   # 5 хв
done
