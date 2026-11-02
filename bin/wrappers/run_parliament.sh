#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
while true; do
  python3 parliament_executor_v6.py
  rc=$?
  echo "[wrap:parliament] exit=$rc $(date +%H:%M:%S) → sleep 10"
  sleep 300
done
