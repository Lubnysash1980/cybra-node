#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
LOG="$CYBRA/logs/cybra-git.log"; mkdir -p "$(dirname "$LOG")"

echo "═══ CYBRA-GIT INSTALL ═══"
for c in git jq pm2 bash redis-cli; do
  command -v "$c" >/dev/null && echo "  ✅ $c" || echo "  ❌ $c missing"
done

# untrack secrets/runtime
"$MOD/bin/untrack.sh"

# gitignore fix
"$MOD/bin/doctor.sh" --fix >/dev/null 2>&1 && echo "  ✅ doctor --fix"

# старий autogit в pm2 — видалити, поставити новий
pm2 delete cybra-autogit 2>/dev/null
pm2 start "$MOD/bin/autogit.sh" --name cybra-autogit --interpreter bash --max-memory-restart 65M -- --daemon 300 2>&1 | grep -E "online|error" | head -1
pm2 save --force >/dev/null 2>&1

# одразу перший коміт
cd "$CYBRA"
git add -A
git -c user.name="cybra" -c user.email="cybra@local" commit -m "chore(cybra-git): install module v1.0.0" 2>/dev/null && echo "  ✓ initial commit"
git push 2>&1 | tail -2

echo "═══ DONE ═══"
