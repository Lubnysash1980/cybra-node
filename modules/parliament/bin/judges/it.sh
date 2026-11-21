#!/data/data/com.termux/files/usr/bin/bash
# IT judge: rejects destructive, approves safe patterns
set -u
PROP=$(cat); EXEC=$(echo "$PROP" | jq -r '.exec // ""'); GOAL=$(echo "$PROP" | jq -r '.goal // ""')
if echo "$EXEC" | grep -qE '(rm -rf /|pm2 delete all|kill -9 1($|[^0-9]))'; then
  jq -n '{verdict:"reject",score:0,reason:"destructive pattern detected"}'; exit 0
fi
if echo "$EXEC" | grep -qE '^pm2 (restart|reload)'; then
  jq -n '{verdict:"approve",score:80,reason:"pm2 restart is safe"}'; exit 0
fi
if echo "$EXEC" | grep -qE '\b(rm|dd|mkfs)\b'; then
  jq -n '{verdict:"reject",score:10,reason:"filesystem mutation"}'; exit 0
fi
jq -n --arg g "$GOAL" '{verdict:"approve",score:50,reason:("no objection: "+$g)}'
