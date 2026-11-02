#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
STATE="$MOD/state"; mkdir -p "$STATE"

auto_ok(){ [ -f "$CYBRA/.cache/autowatch.pid" ] && kill -0 "$(cat "$CYBRA/.cache/autowatch.pid" 2>/dev/null)" 2>/dev/null && echo true || echo false; }
bg_ok(){   [ -f "$CYBRA/.cache/bg_dump.pid" ]   && kill -0 "$(cat "$CYBRA/.cache/bg_dump.pid" 2>/dev/null)"   2>/dev/null && echo true || echo false; }
git_ok(){  pm2 describe cybra-autogit >/dev/null 2>&1 && pm2 jlist 2>/dev/null | jq -e '.[]|select(.name=="cybra-autogit" and .pm2_env.status=="online")' >/dev/null && echo true || echo false; }

AUTO=$(auto_ok); BG=$(bg_ok); GIT=$(git_ok)
LASTC=$(ls -1dt "$CYBRA"/dumps/components/comp_*/ 2>/dev/null | head -1 | xargs -r basename)
LASTG=$(ls -1dt "$CYBRA"/dumps/dump_*/ 2>/dev/null | head -1 | xargs -r basename)
COLOR="green"
[ "$AUTO" = "false" ] && COLOR="red"
[ "$BG" = "false" ] && COLOR="red"

cat > "$STATE/status.json" << J
{
  "ts": $(date +%s),
  "iso": "$(date -Iseconds)",
  "color": "$COLOR",
  "autowatch": $AUTO,
  "bg_dump": $BG,
  "autogit": $GIT,
  "last_component": "$LASTC",
  "last_global": "$LASTG",
  "license": "MIT",
  "version": "1.0.0"
}
J

redis-cli SET stakeawtodump:status "$(cat "$STATE/status.json")" >/dev/null 2>&1
redis-cli SET stakeawtodump:color "$COLOR" >/dev/null 2>&1
[ -n "$LASTC" ] && redis-cli SET stakeawtodump:last_dump "$LASTC" >/dev/null 2>&1

# вивід
case "${1:-text}" in
  json) cat "$STATE/status.json" ;;
  short) echo "$COLOR $([ "$AUTO" = "true" ] && echo A || echo -)$([ "$BG" = "true" ] && echo D || echo -)$([ "$GIT" = "true" ] && echo G || echo -)" ;;
  *)
    echo "╔══════════ stakeawtodump ══════════╗"
    printf "║ color: %-28s ║\n" "$COLOR"
    printf "║ autowatch: %-22s ║\n" "$AUTO"
    printf "║ bg_dump:   %-22s ║\n" "$BG"
    printf "║ autogit:   %-22s ║\n" "$GIT"
    printf "║ last comp: %-22s ║\n" "$LASTC"
    printf "║ last glob: %-22s ║\n" "$LASTG"
    echo "╚═══════════════════════════════════════╝"
    ;;
esac
