#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
B=$(git branch --show-current)
git pull --rebase origin "$B" 2>&1 | tail -3
git push 2>&1 | tail -3
