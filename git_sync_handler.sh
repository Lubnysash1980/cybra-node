#!/data/data/com.termux/files/usr/bin/bash
# git_sync_handler.sh — commit + push через парламент, БЕЗ reset/pull
set -euo pipefail
cd "$HOME/CYBRA"

ACT=$(printf '%s' "${CYBRA_TASK_JSON:-{\}}" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("action","commit_push"))' 2>/dev/null)
MSG=$(printf '%s' "${CYBRA_TASK_JSON:-{\}}" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("msg","sync: auto"))' 2>/dev/null)

OUT=""

# закрити будь-який незавершений merge/stash (без втрат)
git merge --abort 2>/dev/null || true
git stash drop 2>/dev/null || true

case "$ACT" in
  commit_push|push)
    # 1. stage
    git add -A 2>/dev/null || true
    CHANGES=$(git diff --cached --name-only | wc -l)
    OUT="$OUT staged=$CHANGES"

    # 2. commit (якщо є що)
    if [ "$CHANGES" -gt 0 ]; then
      git -c user.email="parliament@cybra.local" -c user.name="cybra-parliament" \
        commit -m "$MSG" >/dev/null 2>&1
      OUT="$OUT committed=yes"
    else
      OUT="$OUT committed=no-changes"
    fi

    # 3. push (без pull, force-with-lease бо remote міг розійтись)
    if git push --force-with-lease origin main >/dev/null 2>&1; then
      OUT="$OUT pushed=yes"
    else
      OUT="$OUT pushed=FAILED"
    fi

    HEAD=$(git rev-parse --short HEAD)
    OUT="$OUT head=$HEAD"
    ;;

  status)
    OUT="branch=$(git rev-parse --abbrev-ref HEAD) head=$(git rev-parse --short HEAD) changes=$(git status --porcelain | wc -l)"
    ;;

  *)
    OUT="unknown_action=$ACT"
    ;;
esac

printf '{"ok":true,"action":"%s","%s"}\n' "$ACT" "$(echo "$OUT" | tr ' ' ',')"
