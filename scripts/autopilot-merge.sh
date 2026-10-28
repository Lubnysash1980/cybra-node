#!/data/data/com.termux/files/usr/bin/bash
# Merge an autopilot/* branch into main.
# Usage: scripts/autopilot-merge.sh autopilot/2026-10-28

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <autopilot-branch>"
  echo
  echo "Available autopilot branches on origin:"
  git ls-remote --heads origin 'refs/heads/autopilot/*' | sed 's|.*refs/heads/||'
  exit 1
fi

BRANCH="$1"

git fetch origin "$BRANCH"
git checkout main
git pull --ff-only origin main

# Show what will be merged
echo "=== Changes to be merged from $BRANCH ==="
git log --oneline main.."origin/$BRANCH"
echo
read -r -p "Merge $BRANCH into main? [y/N] " ans
[[ "$ans" =~ ^[Yy]$ ]] || { echo "aborted"; exit 1; }

git merge --no-ff "origin/$BRANCH" -m "merge: $BRANCH into main"
git push origin main
echo "✅ merged $BRANCH -> main"
