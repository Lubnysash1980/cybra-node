#!/data/data/com.termux/files/usr/bin/bash
# Ops judge: uptime & cost
set -u
PROP=$(cat); EXEC=$(echo "$PROP" | jq -r '.exec // ""')
if echo "$EXEC" | grep -qE '^pm2 (restart|reload)'; then
  jq -n '{verdict:"approve",score:70,reason:"restart ok, downtime<5s"}'; exit 0
fi
if echo "$EXEC" | grep -qE '\bkill\b'; then
  jq -n '{verdict:"reject",score:20,reason:"kill disrupts uptime"}'; exit 0
fi
jq -n '{verdict:"approve",score:60,reason:"no ops concern"}'
