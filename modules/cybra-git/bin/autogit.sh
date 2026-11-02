#!/data/data/com.termux/files/usr/bin/bash
# autogit.sh — daemon: commit + push кожні N сек. Stale-lock safe.
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/autogit.log"; mkdir -p "$(dirname "$LOG")"
LOCK="$CYBRA/.cache/autogit.lock"; mkdir -p "$CYBRA/.cache"
STATE="$CYBRA/modules/cybra-git/state"; mkdir -p "$STATE"

log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

ensure_gitignore(){
  touch .gitignore
  for pat in dumps/ logs/ queue/ .cache/ .pm2/ state/snapshots/ '*.log' '*.pid' \
             '*.env' '!*.env.example' '*.pem' '*.key' 'id_rsa*' api_jwt_secret.txt \
             '__pycache__/' '*.pyc' .venv/ venv/ EOF '.done-*' '*.lock'; do
    grep -qxF "$pat" .gitignore || echo "$pat" >> .gitignore
  done
}

do_once(){
  if ! mkdir "$LOCK" 2>/dev/null; then
    if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +5 2>/dev/null)" ]; then
      rmdir "$LOCK" 2>/dev/null
      mkdir "$LOCK" 2>/dev/null || { log "skip (locked)"; return 0; }
    else
      log "skip (locked)"; return 0
    fi
  fi
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT

  ensure_gitignore

  if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    log "clean"; return 0
  fi

  local n=$(git status --porcelain | wc -l)
  git add -A
  git -c user.name="cybra-autogit" -c user.email="autogit@cybra.local" \
      commit -m "auto: $n files @ $(date '+%F %T')" >/dev/null 2>&1 || { log "commit failed"; return 1; }

  # pull --rebase перед push
  if git remote get-url origin >/dev/null 2>&1; then
    git pull --rebase origin "$(git branch --show-current)" >>"$LOG" 2>&1 || true
    if git push >>"$LOG" 2>&1; then
      log "✓ pushed $n files"
      echo "{\"ts\":$(date +%s),\"files\":$n,\"status\":\"pushed\"}" >> "$STATE/commits.jsonl"
    else
      log "✗ push failed — rollback"
      git reset --soft HEAD~1 2>/dev/null
      return 1
    fi
  else
    log "✓ committed $n (no remote)"
  fi
}

case "${1:---daemon}" in
  --once)   do_once ;;
  --daemon) I="${2:-300}"; log "daemon start interval=${I}s"
            while true; do do_once; sleep "$I"; done ;;
  --status) echo "remote: $(git remote get-url origin 2>/dev/null || echo NONE)"
            echo "branch: $(git branch --show-current 2>/dev/null)"
            echo "ahead : $(git rev-list --count @{u}..HEAD 2>/dev/null || echo ?)"
            echo "dirty : $(git status --porcelain | wc -l)"
            echo "last  : $(git log --oneline -1 2>/dev/null)" ;;
  *) echo "usage: $0 [--once|--daemon N|--status]" ;;
esac
