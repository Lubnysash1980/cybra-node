#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
PIDFILE="$CYBRA/.cache/bg_dump.pid"
LOG="$CYBRA/logs/bg_dump.log"
COMP="${COMP:-60}"; GLOBAL="${GLOBAL:-900}"; GODCHECK="${GODCHECK:-30}"
mkdir -p "$CYBRA/.cache" "$CYBRA/logs"
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
  echo "already running"; exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT
log "═══ BG DUMP START ═══ pid=$$ comp=${COMP}s global=${GLOBAL}s godcheck=${GODCHECK}s"
command -v termux-wake-lock >/dev/null && termux-wake-lock 2>/dev/null && log "wake-lock ok"

ensure_god(){
  local n; n=$(pgrep -f "PM2.*God Daemon" 2>/dev/null | wc -l)
  if [ "$n" -eq 0 ]; then
    log "god DEAD → resurrect"
    pm2 resurrect >> "$LOG" 2>&1; sleep 3
    pm2 save --force >> "$LOG" 2>&1
  fi
}
do_comp(){
  if [ -x "$CYBRA/bin/cybra_dump_components.sh" ]; then
    "$CYBRA/bin/cybra_dump_components.sh" >> "$LOG" 2>&1 && log "comp dump ok" || log "comp dump fail"
  else
    log "comp dump fail (missing cybra_dump_components.sh)"
  fi
}
do_global(){
  if [ -x "$CYBRA/bin/cybra_dump.sh" ]; then
    "$CYBRA/bin/cybra_dump.sh" >> "$LOG" 2>&1 && log "global dump ok" || log "global dump fail"
  fi
}
LAST_GOD=0; LAST_COMP=0; LAST_GLOBAL=0
while true; do
  NOW=$(date +%s)
  [ $((NOW - LAST_GOD))    -ge "$GODCHECK" ] && { ensure_god;  LAST_GOD=$NOW; }
  [ $((NOW - LAST_COMP))   -ge "$COMP"     ] && { do_comp;     LAST_COMP=$NOW; }
  [ $((NOW - LAST_GLOBAL)) -ge "$GLOBAL"   ] && { do_global;   LAST_GLOBAL=$NOW; }
  sleep 15
done
