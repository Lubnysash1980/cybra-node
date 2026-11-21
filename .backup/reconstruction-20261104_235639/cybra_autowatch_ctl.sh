#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; PIDFILE="$CYBRA/.cache/autowatch.pid"; LOG="$CYBRA/logs/autowatch.log"
case "${1:-status}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
      echo "already running pid=$(cat "$PIDFILE")"; exit 0
    fi
    cd "$CYBRA"
    setsid nohup bin/cybra_autowatch.sh >/dev/null 2>&1 < /dev/null &
    sleep 2
    [ -f "$PIDFILE" ] && echo "✓ started pid=$(cat "$PIDFILE")" || { echo "✗ failed"; exit 1; }
    ;;
  stop)
    [ -f "$PIDFILE" ] && { P=$(cat "$PIDFILE"); kill "$P" 2>/dev/null; sleep 1; kill -9 "$P" 2>/dev/null; rm -f "$PIDFILE"; rmdir "$CYBRA/.cache/autowatch.lock" 2>/dev/null; echo "stopped pid=$P"; } || echo "not running"
    ;;
  status)
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null && {
      P=$(cat "$PIDFILE")
      echo "RUNNING pid=$P uptime=$(ps -o etime= -p "$P" 2>/dev/null | tr -d ' ')"
      echo "── bg_dump: $([ -f "$CYBRA/.cache/bg_dump.pid" ] && kill -0 "$(cat "$CYBRA/.cache/bg_dump.pid" 2>/dev/null)" 2>/dev/null && echo RUNNING || echo STOPPED)"
      echo "── pm2 god: $(pgrep -f "PM2.*God Daemon" 2>/dev/null | wc -l)"
      echo "── online:  $(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length' 2>/dev/null || echo ?)"
      tail -5 "$LOG"
    } || echo "STOPPED"
    ;;
  log) tail -n "${2:-30}" "$LOG" ;;
  *) echo "usage: $0 {start|stop|status|log}"; exit 1 ;;
esac
