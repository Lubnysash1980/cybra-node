#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
STATE="$CYBRA/modules/cybra-git/state"; mkdir -p "$STATE"

B=$(git branch --show-current 2>/dev/null || echo "?")
R=$(git remote get-url origin 2>/dev/null || echo "")
AHEAD=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
BEHIND=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0)
DIRTY=$(git status --porcelain 2>/dev/null | wc -l)
SECRETS=$(git ls-files 2>/dev/null | grep -cE '(^|/)\.env$|api_jwt_secret|\.pem$|\.key$' || echo 0)
LAST=$(git log --oneline -1 2>/dev/null || echo "none")
AUTOGIT=$(pm2 jlist 2>/dev/null | jq -r '.[]|select(.name=="cybra-autogit")|.pm2_env.status' 2>/dev/null || echo "missing")

COLOR="green"
[ -z "$R" ] && COLOR="red"
[ "$AUTOGIT" != "online" ] && COLOR="yellow"
[ "$SECRETS" -gt 0 ] && COLOR="red"

cat > "$STATE/status.json" << J
{
  "ts": $(date +%s),
  "iso": "$(date -Iseconds)",
  "color": "$COLOR",
  "branch": "$B",
  "remote": "$R",
  "ahead": $AHEAD,
  "behind": $BEHIND,
  "dirty": $DIRTY,
  "secrets_tracked": $SECRETS,
  "autogit": "$AUTOGIT",
  "last_commit": "$LAST"
}
J

redis-cli SET cybra-git:status "$(cat "$STATE/status.json")" >/dev/null 2>&1
redis-cli SET cybra-git:color "$COLOR" >/dev/null 2>&1
redis-cli SET cybra-git:last_commit "$LAST" >/dev/null 2>&1

case "${1:-text}" in
  json) cat "$STATE/status.json" ;;
  short) echo "$COLOR" ;;
  *)
    echo "╔═══════════════ cybra-git ═══════════════╗"
    printf "║ %-41s║\n" "color: $COLOR"
    printf "║ %-41s║\n" "branch: $B   ahead: $AHEAD  behind: $BEHIND"
    printf "║ %-41s║\n" "dirty: $DIRTY   secrets: $SECRETS"
    printf "║ %-41s║\n" "autogit: $AUTOGIT"
    printf "║ %-41s║\n" "last: $LAST"
    echo "╚════════════════════════════════════════╝"
    ;;
esac
