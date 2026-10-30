#!/usr/bin/env bash
set -uo pipefail
export PM2_HOME="${PM2_HOME:-$HOME/.pm2}"
mkdir -p "$PM2_HOME/logs"
while true; do
  n=$(pm2 jlist 2>/dev/null | jq 'length' 2>/dev/null || echo ?)
  s=$(jq -r .score_pct "$PM2_HOME/evolution/score.json" 2>/dev/null || echo ?)
  echo "[$(date +%FT%TZ)] procs=$n score=$s" >> "$PM2_HOME/logs/complexity.log"
  sleep 60
done
