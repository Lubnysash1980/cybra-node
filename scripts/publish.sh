#!/data/data/com.termux/files/usr/bin/bash
# Публікація в git
set -eu

TARGET="${1:-.}"
cd "$TARGET"

if [ ! -d .git ]; then
    git init
    git config user.email "cybra@local"
    git config user.name  "CYBRA Node"
fi

git add -A
git commit -m "CYBRA build $(date -u +%Y%m%dT%H%M%SZ)" || true

echo "Local commit created."
echo ""
echo "Щоб опублікувати:"
echo "  git remote add origin <your-repo-url>"
echo "  git branch -M main"
echo "  git push -u origin main"
