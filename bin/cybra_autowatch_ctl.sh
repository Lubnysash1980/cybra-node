#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"
PIDFILE="$CYBRA/.cache/autowatch.pid"
LOG="$CYBRA/logs/autowatch.log"

case "${1:-status}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "already running pid=$(cat "$PIDFILE")"; exit 0
    fi
    cd "$CYBRA"
    setsid nohup bin/cybra_autowatch.sh >/dev/null 2>&1 < /dev/null &
    sleep 2
    if [ -f "$PIDFILE" ]; then echo "✓ started pid=$(cat "$PIDFILE")"
    else echo "✗ failed — check $LOG"; exit 1; fi
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      P=$(cat "$PIDFILE"); kill "$P" 2>/dev/null; sleep 1; kill -9 "$P" 2>/dev/null
      rm -f "$PIDFILE"; rmdir "$CYBRA/.cache/autowatch.lock" 2>/dev/null
      echo "stopped pid=$P"
    else echo "not running"; fi
    ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      P=$(cat "$PIDFILE")
      echo "RUNNING pid=$P uptime=$(ps -o etime= -p "$P" 2>/dev/null | tr -d ' ')"
      echo ""
      echo "── bg_dump: $([ -f "$CYBRA/.cache/bg_dump.pid" ] && kill -0 "$(cat "$CYBRA/.cache/bg_dump.pid")" 2>/dev/null && echo "RUNNING $(cat "$CYBRA/.cache/bg_dump.pid")" || echo "STOPPED")"
      echo "── pm2 god: $(pgrep -f "PM2.*God Daemon" 2>/dev/null | wc -l)"
      echo "── online:  $(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length' 2>/dev/null || echo '?')/$(pm2 jlist 2>/dev/null | jq 'length' 2>/dev/null || echo '?')"
      echo ""
      echo "── last 8 log ──"; tail -8 "$LOG" 2>/dev/null
    else echo "STOPPED"; fi
    ;;
  restart) "$0" stop; sleep 1; "$0" start ;;
  log) tail -n "${2:-30}" "$LOG" ;;
  *) echo "usage: $0 {start|stop|status|restart|log [N]}"; exit 1 ;;
esac
