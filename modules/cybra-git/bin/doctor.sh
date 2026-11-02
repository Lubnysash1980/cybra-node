#!/data/data/com.termux/files/usr/bin/bash
# doctor.sh — діагностика git-стану. --fix виправляє.
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
FIX="${1:-}"
RC=0
ok(){   echo "  ✅ $*"; }
bad(){  echo "  ❌ $*"; RC=1; }
info(){ echo "  ℹ $*"; }

echo "═══ CYBRA-GIT DOCTOR ═══"

[ -d .git ] && ok "repo" || { bad "no .git"; [ "$FIX" = "--fix" ] && git init -q && git branch -M main; }
B=$(git branch --show-current 2>/dev/null); [ -n "$B" ] && ok "branch=$B" || bad "no branch"
R=$(git remote get-url origin 2>/dev/null); [ -n "$R" ] && ok "remote=$R" || bad "no origin"
U=$(git config user.name 2>/dev/null); [ -n "$U" ] && ok "user=$U" || { bad "no user"; [ "$FIX" = "--fix" ] && git config user.name cybra && git config user.email cybra@local; }

# gitignore
need=("dumps/" "logs/" "queue/" ".cache/" ".pm2/" "state/snapshots/" "*.log" "*.pid"
      "*.env" "!*.env.example" "*.pem" "*.key" "id_rsa*" "api_jwt_secret.txt"
      "__pycache__/" "*.pyc" ".venv/" "venv/" "EOF" ".done-*" "*.lock")
miss=""
for pat in "${need[@]}"; do
  grep -qxF "$pat" .gitignore 2>/dev/null || miss="$miss$pat\n"
done
if [ -z "$miss" ]; then ok ".gitignore complete"
else
  bad ".gitignore missing $(echo -e "$miss" | wc -l) patterns"
  if [ "$FIX" = "--fix" ]; then
    { echo ""; echo "# cybra-git auto"; echo -e "$miss"; } >> .gitignore
    ok "fixed .gitignore"
  fi
fi

# секрети в tracking
SEC=$(git ls-files 2>/dev/null | grep -E '(^|/)\.env$|api_jwt_secret|\.pem$|\.key$|id_rsa' | head -20)
if [ -z "$SEC" ]; then ok "no tracked secrets"
else
  bad "tracked secrets: $(echo "$SEC" | wc -l)"
  [ "$FIX" = "--fix" ] && { echo "$SEC" | xargs -r git rm --cached -q 2>/dev/null; ok "untracked secrets"; }
fi

# runtime в tracking
RUN=$(git ls-files 2>/dev/null | grep -E '^(dumps|logs|queue|\.cache|\.pm2)/' | head -20)
if [ -z "$RUN" ]; then ok "no tracked runtime"
else
  bad "tracked runtime: $(echo "$RUN" | wc -l)"
  [ "$FIX" = "--fix" ] && { echo "$RUN" | xargs -r git rm --cached -q 2>/dev/null; ok "untracked runtime"; }
fi

# remote reachable
if [ -n "$R" ]; then
  git ls-remote --exit-code origin HEAD >/dev/null 2>&1 && ok "remote reachable" || bad "remote unreachable"
fi

AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "?"); BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "?")
info "ahead=$AHEAD behind=$BEHIND"
info "dirty=$(git status --porcelain 2>/dev/null | wc -l) .git=$(du -sh .git 2>/dev/null | cut -f1)"

# autogit у pm2
pm2 describe cybra-autogit >/dev/null 2>&1 && ok "cybra-autogit online" || {
  bad "cybra-autogit missing"
  if [ "$FIX" = "--fix" ] && [ -x "$CYBRA/modules/cybra-git/bin/autogit.sh" ]; then
    pm2 start "$CYBRA/modules/cybra-git/bin/autogit.sh" --name cybra-autogit --interpreter bash --max-memory-restart 65M >/dev/null 2>&1
    pm2 save --force >/dev/null 2>&1
    ok "started autogit"
  fi
}

echo "═══ $( [ $RC -eq 0 ] && echo "OK" || echo "WARNINGS" ) ═══"
exit $RC
