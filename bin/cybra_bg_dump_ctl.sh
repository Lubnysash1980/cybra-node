#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"
PIDFILE="$CYBRA/.cache/bg_dump.pid"
LOG="$CYBRA/logs/bg_dump.log"

case "${1:-status}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "already running pid=$(cat "$PIDFILE")"
      exit 0
    fi
    cd "$CYBRA"
    setsid nohup bin/cybra_bg_dump.sh >/dev/null 2>&1 < /dev/null &
    sleep 2
    if [ -f "$PIDFILE" ]; then
      echo "✓ started pid=$(cat "$PIDFILE")"
    else
      echo "✗ failed — check $LOG"
      exit 1
    fi
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      PID=$(cat "$PIDFILE")
      kill "$PID" 2>/dev/null
      sleep 1
      kill -9 "$PID" 2>/dev/null
      rm -f "$PIDFILE"
      rmdir "$CYBRA/.cache/bg_dump.lock" 2>/dev/null
      echo "stopped pid=$PID"
    else
      echo "not running"
    fi
    ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "RUNNING pid=$(cat "$PIDFILE")"
      echo "uptime: $(ps -o etime= -p "$(cat "$PIDFILE")" 2>/dev/null | tr -d ' ')"
      echo ""
      echo "── last 8 log lines ──"
      tail -8 "$LOG" 2>/dev/null
    else
      echo "STOPPED"
    fi
    ;;
  restart)
    "$0" stop
    sleep 1
    "$0" start
    ;;
  log)
    tail -n "${2:-30}" "$LOG"
    ;;
  *)
    echo "usage: $0 {start|stop|status|restart|log [N]}"
    exit 1
    ;;
esac
