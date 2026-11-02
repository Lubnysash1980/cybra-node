#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
MSG="${*:-manual commit $(date '+%F %T')}"
git add -A
git -c user.name="cybra" -c user.email="cybra@local" commit -m "$MSG" || { echo "nothing to commit"; exit 0; }
echo "✓ committed: $MSG"
