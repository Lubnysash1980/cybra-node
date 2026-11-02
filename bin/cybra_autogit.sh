#!/data/data/com.termux/files/usr/bin/bash
# cybra_autogit.sh — авто-коміт + push з дебаунсом.
# Usage: cybra_autogit.sh [--once|--daemon]
set -u
CYBRA="$HOME/CYBRA"
cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/autogit.log"
LOCK="$CYBRA/.cache/autogit.lock"
mkdir -p "$(dirname "$LOG")" "$CYBRA/.cache"

log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

# ── .gitignore (ідемпотентно) ──
ensure_ignore() {
  touch .gitignore
  for pat in \
    "dumps/" "queue/" "logs/" "state/snapshots/" ".cache/" \
    "node/latest" "node/snap_*/" "node/best_*.json" "node/stage_history.jsonl" \
    ".pm2/" "*.log" "*.pid" "api_jwt_secret.txt" \
    "__pycache__/" "*.pyc" ".venv/" "venv/"; do
    grep -qxF "$pat" .gitignore || echo "$pat" >> .gitignore
  done
}

# ── один цикл ──
do_once() {
  # запобігти паралельним запускам
  if ! mkdir "$LOCK" 2>/dev/null; then
    log "skip (locked)"
    return 0
  fi
  trap 'rmdir "$LOCK" 2>/dev/null' EXIT

  ensure_ignore

  # нічого не змінилось?
  if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    log "clean — nothing to do"
    return 0
  fi

  local files=$(git status --porcelain | wc -l)
  local ts=$(date '+%Y-%m-%d %H:%M:%S')
  local host=$(hostname 2>/dev/null || echo termux)

  git add -A
  git -c user.name="cybra-autogit" -c user.email="autogit@cybra.local" \
      commit -m "auto: $files files @ $ts [$host]" \
      -m "stage: $(jq -r '.stage // "?"' state/stage.json 2>/dev/null) | manifest: $(jq -r '.overall.color // "?"' state/manifest.json 2>/dev/null) $(jq -r '.overall.percent // "?"' state/manifest.json 2>/dev/null)%" \
      >/dev/null 2>&1 || { log "commit failed"; return 1; }

  # push (якщо є remote)
  if git remote get-url origin >/dev/null 2>&1; then
    if git push >>"$LOG" 2>&1; then
      log "✓ pushed $files files"
    else
      log "✗ push failed — will retry next cycle"
      git reset --soft HEAD~1 2>/dev/null   # відкат коміта, спробуємо наступного разу
      return 1
    fi
  else
    log "✓ committed locally (no remote)"
  fi
}

# ── основний режим ──
case "${1:---once}" in
  --once)
    do_once
    ;;
  --daemon)
    INTERVAL="${2:-300}"   # 5 хв за замовч.
    log "daemon start, interval=${INTERVAL}s"
    while true; do
      do_once
      sleep "$INTERVAL"
    done
    ;;
  --status)
    echo "═══ AUTOGIT STATUS ═══"
    echo "remote: $(git remote get-url origin 2>/dev/null || echo NONE)"
    echo "branch: $(git branch --show-current 2>/dev/null || echo ?)"
    echo "ahead : $(git rev-list --count @{u}..HEAD 2>/dev/null || echo ?)"
    echo "dirty : $(git status --porcelain | wc -l) files"
    echo "last  : $(git log --oneline -1 2>/dev/null)"
    echo "log   : $LOG"
    ;;
  *)
    echo "usage: cybra_autogit.sh [--once|--daemon N|--status]"
    exit 1
    ;;
esac
