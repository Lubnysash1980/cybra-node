#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
INTERVAL="${COMP_DUMP_INTERVAL:-300}"   # 5 хв
echo "[wrap:comp-dump] start interval=${INTERVAL}s"
while true; do
  bin/cybra_dump_components.sh
  sleep "$INTERVAL"
done
