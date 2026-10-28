#!/data/data/com.termux/files/usr/bin/bash
# Sync autopilot-generated module changes to a dated branch
# WITHOUT touching the main working tree (uses git worktree).

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$REPO_ROOT" ] && { echo "[sync] not in git repo"; exit 0; }
cd "$REPO_ROOT"

CURRENT="$(git rev-parse --abbrev-ref HEAD)"
[ "$CURRENT" != "main" ] && { echo "[sync] on '$CURRENT', expected main — skip"; exit 0; }

# Nothing to sync?
if git diff --quiet -- modules/ && [ -z "$(git ls-files --others --exclude-standard modules/)" ]; then
  echo "[sync] no module changes"
  exit 0
fi

BRANCH="autopilot/$(date +%Y-%m-%d)"
WORKTREE="$REPO_ROOT/.autopilot-worktree"

# Prepare worktree
if ! git worktree list | grep -q "$WORKTREE"; then
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git worktree add "$WORKTREE" "$BRANCH" >/dev/null
  else
    git worktree add -b "$BRANCH" "$WORKTREE" main >/dev/null
  fi
else
  ( cd "$WORKTREE" && cur=$(git rev-parse --abbrev-ref HEAD) && [ "$cur" != "$BRANCH" ] && \
    { git checkout "$BRANCH" 2>/dev/null || git checkout -b "$BRANCH"; } )
fi

# Sync modules/ from main worktree into autopilot worktree
rsync -a --delete --exclude='.git' modules/ "$WORKTREE/modules/"

# Commit in worktree
cd "$WORKTREE"
git add -A modules/
if git diff --cached --quiet; then
  echo "[sync] no diff after rsync"
  cd "$REPO_ROOT"
  exit 0
fi
git commit -m "chore(autopilot): module snapshot $(date -u +%FT%TZ)" >/dev/null
git push -u origin "$BRANCH" >/dev/null
cd "$REPO_ROOT"

echo "[sync] pushed to $BRANCH"
