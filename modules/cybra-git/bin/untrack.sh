#!/data/data/com.termux/files/usr/bin/bash
# untrack.sh — прибрати секрети/runtime з git (файли лишаються на диску).
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1

echo "═══ UNTRACK ═══"

# 1. секрети
SEC=$(git ls-files 2>/dev/null | grep -E '(^|/)\.env$|api_jwt_secret|\.pem$|\.key$|id_rsa' || true)
if [ -n "$SEC" ]; then
  echo "$SEC" | while read -r f; do git rm --cached -q "$f" 2>/dev/null && echo "  ✂ $f"; done
fi

# 2. runtime
RUN=$(git ls-files 2>/dev/null | grep -E '^(dumps|logs|queue|parliament_core|\.cache|\.pm2)/|^EOF$' | head -5000 || true)
if [ -n "$RUN" ]; then
  echo "$RUN" | while read -r f; do git rm --cached -q "$f" 2>/dev/null; done
  echo "  ✂ untracked $(echo "$RUN" | wc -l) runtime files"
fi

# 3. broken .lock та .done-*
BROKEN=$(git ls-files 2>/dev/null | grep -E '\.lock$|/\.done-' | head -5000 || true)
[ -n "$BROKEN" ] && echo "$BROKEN" | xargs -r git rm --cached -q 2>/dev/null

echo "═══ after ═══"
echo "  tracked secrets: $(git ls-files 2>/dev/null | grep -cE '(^|/)\.env$|api_jwt_secret|\.pem$|\.key$')"
echo "  tracked runtime: $(git ls-files 2>/dev/null | grep -cE '^(dumps|logs|queue|parliament_core)/')"
