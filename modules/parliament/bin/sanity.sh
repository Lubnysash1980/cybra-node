#!/data/data/com.termux/files/usr/bin/bash
# sanity.sh — structural health check. Exit 0 if OK, 1 if not.
set -u
CYBRA="$HOME/CYBRA"
god=$(pgrep -f 'PM2.*God Daemon' | wc -l)
errored=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="errored")]|length' 2>/dev/null || echo 0)
bg=$(kill -0 "$(cat "$CYBRA/.cache/bg_dump.pid" 2>/dev/null)" 2>/dev/null && echo 1 || echo 0)
aw=$(kill -0 "$(cat "$CYBRA/.cache/autowatch.pid" 2>/dev/null)" 2>/dev/null && echo 1 || echo 0)
issues=""
[ "$god" -lt 1 ]        && issues="$issues god=0"
[ "$errored" -gt 0 ]    && issues="$issues errored=$errored"
[ "$bg" -ne 1 ]         && issues="$issues bg_dump=0"
[ "$aw" -ne 1 ]         && issues="$issues autowatch=0"
if [ -z "$issues" ]; then
  echo "OK god=$god errored=0 bg_dump=1 autowatch=1"; exit 0
else
  echo "FAIL$issues"; exit 1
fi
