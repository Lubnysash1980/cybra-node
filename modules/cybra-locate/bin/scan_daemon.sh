#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
INTERVAL="${LOCATE_INTERVAL:-600}"
echo "[locate-daemon] start interval=${INTERVAL}s"
while true; do
  bin/scan.sh scan
  bin/status.sh >/dev/null 2>&1
  sleep "$INTERVAL"
done
