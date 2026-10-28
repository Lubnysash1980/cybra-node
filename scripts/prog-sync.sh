#!/data/data/com.termux/files/usr/bin/bash
# Usage: prog-sync.sh <a|b>
set -euo pipefail
[ $# -lt 1 ] && { echo "usage: $0 <a|b>"; exit 1; }
X="$1"; case "$X" in a|b) ;; *) echo "bad prog"; exit 1;; esac

REPO_ROOT="$(git rev-parse --show-toplevel)"; cd "$REPO_ROOT"
SRC="programs/prog_${X}"; BRANCH="prog/${X}"; WT="$REPO_ROOT/.prog-${X}-worktree"

[ -d "$SRC" ] || { echo "[sync-$X] no $SRC"; exit 0; }
[ -n "$(ls -A "$SRC" 2>/dev/null)" ] || { echo "[sync-$X] empty, skip"; exit 0; }

if ! git worktree list | grep -q "$WT"; then
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git worktree add "$WT" "$BRANCH" >/dev/null
  else
    git worktree add -b "$BRANCH" "$WT" main >/dev/null
  fi
else
  ( cd "$WT" && cur=$(git rev-parse --abbrev-ref HEAD) && \
    [ "$cur" != "$BRANCH" ] && { git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"; } )
fi

rsync -a --delete --exclude='.git' "$SRC/" "$WT/programs/prog_${X}/"

cd "$WT"
git add -A "programs/prog_${X}/"
if git diff --cached --quiet; then
  echo "[sync-$X] no diff"; cd "$REPO_ROOT"; exit 0
fi
git commit -m "chore(prog-${X}): update $(date -u +%FT%TZ)" >/dev/null
git push -u origin "$BRANCH" >/dev/null
cd "$REPO_ROOT"
echo "[sync-$X] pushed to $BRANCH"
