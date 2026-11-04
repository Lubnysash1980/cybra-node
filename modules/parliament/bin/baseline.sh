#!/data/data/com.termux/files/usr/bin/bash
# baseline.sh — save "100% state" snapshot
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
STATE="$MOD/state"; mkdir -p "$STATE"
god=$(pgrep -f 'PM2.*God Daemon' | wc -l)
online=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length')
errored=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="errored")]|length')
bg=$(kill -0 "$(cat "$CYBRA/.cache/bg_dump.pid" 2>/dev/null)" 2>/dev/null && echo 1 || echo 0)
aw=$(kill -0 "$(cat "$CYBRA/.cache/autowatch.pid" 2>/dev/null)" 2>/dev/null && echo 1 || echo 0)
jq -n --argjson g "$god" --argjson o "$online" --argjson e "$errored" \
      --argjson b "$bg" --argjson a "$aw" --argjson ts "$(date +%s)" \
  '{ts:$ts, god:$g, online:$o, errored:$e, bg_dump:$b, autowatch:$a}' > "$STATE/baseline.json"
echo "✓ baseline saved"
jq . "$STATE/baseline.json"
