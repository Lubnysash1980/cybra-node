#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
git add -A
git -c user.name="cybra" -c user.email="cybra@local" commit -m "sync: $(date '+%F %T')" 2>/dev/null || true
B=$(git branch --show-current)
git pull --rebase origin "$B" 2>&1 | tail -2
git push 2>&1 | tail -2
echo "✓ synced"
