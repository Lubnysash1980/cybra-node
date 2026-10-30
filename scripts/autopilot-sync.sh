#!/usr/bin/env bash
set -euo pipefail
cd "$HOME/CYBRA"
git fetch origin --prune 2>/dev/null || true
git pull --rebase --autostash 2>/dev/null || true
echo "[autopilot-sync] $(date +%FT%TZ) tick"
