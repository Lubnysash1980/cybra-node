#!/data/data/com.termux/files/usr/bin/bash
# Safety judge — power of VETO over destructive actions.
set -u
PROP=$(cat)
EXEC=$(echo "$PROP" | jq -r '.exec // ""')
GOAL=$(echo "$PROP" | jq -r '.goal // ""')
CRIT='(bin|modules|\.pm2|\.cache|\.git)/'
WRITER='(^|[[:space:];&|])(rm|mv|cp|tee|truncate|install|dd|mkfs|shred)([[:space:]]|$)'

veto(){ jq -n --arg r "$1" '{verdict:"reject",score:0,reason:$r}'; exit 0; }

# VETO patterns
echo "$EXEC" | grep -qE '(^|[[:space:];&|])rm([[:space:]]|$)' && veto "rm present — VETO"
echo "$EXEC" | grep -qE "$WRITER" && echo "$EXEC" | grep -qE "$CRIT" \
  && veto "filesystem mutation on critical path — VETO"
echo "$EXEC" | grep -qE ">[[:space:]]*[^&|]*$CRIT" \
  && veto "redirect into critical path — VETO"
echo "$EXEC" | grep -qE '\b(sudo|su[[:space:]]+-c|doas|chmod[[:space:]]+777)\b' \
  && veto "privilege escalation — VETO"
echo "$EXEC" | grep -qE '(curl|wget)[^|]*\|[[:space:]]*(bash|sh)([[:space:]]|$)' \
  && veto "curl|sh — VETO"
echo "$EXEC" | grep -qE 'pm2[[:space:]]+delete[[:space:]]+all' \
  && veto "pm2 delete all — VETO"
echo "$EXEC" | grep -qE '(^|[[:space:];&|])kill[[:space:]]+-9([[:space:]]|$)' \
  && veto "kill -9 — VETO"
echo "$EXEC" | grep -qE '\b(dd|mkfs|shred)[[:space:]]' \
  && veto "destructive disk op — VETO"

# Strong approve
echo "$EXEC" | grep -qE '^pm2[[:space:]]+(restart|reload)[[:space:]]+cybra-' \
  && { jq -n '{verdict:"approve",score:95,reason:"safe pm2 restart cybra-*"}'; exit 0; }
echo "$EXEC" | grep -qE '/(autorestore|rollback)\.sh' \
  && { jq -n '{verdict:"approve",score:95,reason:"restore/rollback safe by design"}'; exit 0; }
echo "$EXEC" | grep -qE '/(bg_dump_ctl|autowatch_ctl|parliament_ctl)\.sh[[:space:]]+(start|status|stop|restart|log)' \
  && { jq -n '{verdict:"approve",score:90,reason:"ctl start/status safe"}'; exit 0; }

jq -n --arg g "$GOAL" '{verdict:"approve",score:70,reason:("no safety concern: "+$g)}'
