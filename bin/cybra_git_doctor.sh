#!/data/data/com.termux/files/usr/bin/bash
# cybra_git_doctor.sh — перевірка git-інтеграції. Виправляє типові проблеми.
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
FIX="${1:-}"

ok(){   echo "  ✅ $*"; }
bad(){  echo "  ❌ $*"; }
fix(){  [ "$FIX" = "--fix" ] && "$@" && ok "fixed"; }

echo "═══ GIT DOCTOR ═══"

# 1. .git
[ -d .git ] && ok "repo initialized" || { bad "no .git"; [ "$FIX" = "--fix" ] && git init && git branch -M main; }

# 2. branch
B=$(git branch --show-current 2>/dev/null)
[ -n "$B" ] && ok "branch: $B" || { bad "detached HEAD"; [ "$FIX" = "--fix" ] && git checkout -B main; }

# 3. remote
R=$(git remote get-url origin 2>/dev/null)
[ -n "$R" ] && ok "remote: $R" || bad "no origin remote"

# 4. user
U=$(git config user.name 2>/dev/null)
[ -n "$U" ] && ok "user: $U" || { bad "no git user"; [ "$FIX" = "--fix" ] && git config user.name cybra && git config user.email cybra@local; }

# 5. .gitignore
if grep -qE "^(dumps|logs|\.cache|queue)/" .gitignore 2>/dev/null; then
  ok ".gitignore has runtime dirs"
else
  bad ".gitignore missing runtime dirs"
  if [ "$FIX" = "--fix" ]; then
    cat >> .gitignore << 'IG'

# runtime
dumps/
logs/
queue/
.cache/
state/snapshots/
node/latest
node/snap_*/
node/best_*.json
node/stage_history.jsonl
.pm2/
*.log
*.pid
api_jwt_secret.txt
.env
.env.*
*.pem
*.key
*.keystore
id_rsa*
__pycache__/
*.pyc
.venv/
venv/
IG
    ok "fixed .gitignore"
  fi
fi

# 6. чи не закомічені секрети
SECRETS=$(git ls-files 2>/dev/null | grep -E "\.(pem|key)$|api_jwt_secret|\.env$|id_rsa" | head -5)
[ -z "$SECRETS" ] && ok "no secrets tracked" || bad "SECRETS TRACKED: $SECRETS"

# 7. чи не закомічені runtime-файли
RUNTIME=$(git ls-files 2>/dev/null | grep -E "^(dumps|logs|queue|\.cache|\.pm2)/" | head -5)
[ -z "$RUNTIME" ] && ok "no runtime files tracked" || { bad "runtime in git: $RUNTIME"; [ "$FIX" = "--fix" ] && git rm -r --cached dumps logs queue .cache .pm2 2>/dev/null; }

# 8. чи можна достукатись до remote (без push)
if [ -n "$R" ]; then
  if git ls-remote --exit-code origin HEAD >/dev/null 2>&1; then
    ok "remote reachable"
  else
    bad "remote NOT reachable (auth?)"
  fi
fi

# 9. чи не diverged
AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "?")
BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "?")
echo "  ℹ ahead=$AHEAD behind=$BEHIND"

# 10. розмір .git
DU=$(du -sh .git 2>/dev/null | cut -f1)
echo "  ℹ .git size: $DU"

# 11. autogit у pm2
if pm2 describe cybra-autogit >/dev/null 2>&1; then
  ok "cybra-autogit in pm2"
else
  bad "cybra-autogit not in pm2"
  if [ "$FIX" = "--fix" ] && [ -x bin/wrappers/run_autogit.sh ]; then
    pm2 start bin/wrappers/run_autogit.sh --name cybra-autogit --interpreter bash --max-memory-restart 65M >/dev/null 2>&1
    pm2 save --force >/dev/null 2>&1
    ok "fixed — started cybra-autogit"
  fi
fi

echo "═══ END ═══"
[ "$FIX" = "--fix" ] || echo "  (запусти з --fix щоб виправити)"
