#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
INTERVAL="${SYNC_INTERVAL:-300}"
echo "[sync-daemon] start interval=${INTERVAL}s"
while true; do
  bin/sync.sh auto
  sleep "$INTERVAL"
done
