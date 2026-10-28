#!/data/data/com.termux/files/usr/bin/bash
# taxi_event → просто логуємо, подія вже оброблена модулем
set -euo pipefail
cd "$HOME/CYBRA"
mkdir -p logs/taxi_events
TASK_JSON="${CYBRA_TASK_JSON:-{\}}"
TS=$(date -u +%FT%TZ)
echo "$TS $TASK_JSON" >> logs/taxi_events/$(date +%Y-%m-%d).log
printf '{"ok":true,"ts":"%s"}\n' "$TS"
