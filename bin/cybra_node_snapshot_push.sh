#!/data/data/com.termux/files/usr/bin/bash
# PUSH NODE — коміт + тег + push у GitHub cybra-node
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date +%Y%m%d_%H%M%S)
TAG="v3.0-node-full-$TS"

echo "═══ PUSH TO NODE @cybra ═══"

# git status
CHANGES=$(git status --short | wc -l)
echo "  changes: $CHANGES files"

# commit
if [ "$CHANGES" -gt 0 ]; then
  git add -A 2>/dev/null
  git commit -m "release: node full snapshot for device transfer ($TS)" 2>&1 | head -2
fi

# tag
git tag -f "$TAG"
echo "  tag: $TAG"

# push
git push origin main 2>&1 | tail -2
git push origin "$TAG" -f 2>&1 | tail -2

# summary
echo ""
echo "═══ NODE READY ═══"
echo "  repo:  $(git config --get remote.origin.url)"
echo "  HEAD:  $(git rev-parse --short HEAD)"
echo "  tag:   $TAG"
echo ""
echo "  на іншому пристрої:"
echo "    git clone $(git config --get remote.origin.url) ~/CYBRA"
echo "    cd ~/CYBRA && git checkout $TAG"
echo "    bash bin/cybra_bootstrap_other_device.sh"
