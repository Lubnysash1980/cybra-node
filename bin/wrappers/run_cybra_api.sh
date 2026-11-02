#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
while true; do
  bash api/run.sh
  rc=$?
  echo "[wrap:cybra-api] exit=$rc $(date +%H:%M:%S) → sleep 60"
  sleep 60
done
