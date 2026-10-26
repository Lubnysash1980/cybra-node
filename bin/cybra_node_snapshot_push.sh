#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date +%Y%m%d_%H%M%S); TAG="v3.0-node-full-$TS"
echo "═══ PUSH TO @cybra ═══"
git add -A 2>/dev/null
git commit -m "release: $TS" 2>&1 | head -2
git tag -f "$TAG"
git push origin main 2>&1 | tail -2
git push origin "$TAG" -f 2>&1 | tail -2
echo "═══ DONE: $TAG ═══"
echo "clone: git clone $(git config --get remote.origin.url) ~/CYBRA"
