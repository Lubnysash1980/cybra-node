#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; PIDFILE="$CYBRA/.cache/bg_dump.pid"; LOG="$CYBRA/logs/bg_dump.log"
case "${1:-status}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
      echo "already running pid=$(cat "$PIDFILE")"; exit 0
    fi
    cd "$CYBRA"
    setsid nohup bin/cybra_bg_dump.sh >/dev/null 2>&1 < /dev/null &
    sleep 2
    [ -f "$PIDFILE" ] && echo "✓ started pid=$(cat "$PIDFILE")" || { echo "✗ failed"; exit 1; }
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      P=$(cat "$PIDFILE"); kill "$P" 2>/dev/null; sleep 1; kill -9 "$P" 2>/dev/null
      rm -f "$PIDFILE"; echo "stopped pid=$P"
    else echo "not running"; fi
    ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
      echo "RUNNING pid=$(cat "$PIDFILE")"; tail -5 "$LOG" 2>/dev/null
    else echo "STOPPED"; fi
    ;;
  log) tail -n "${2:-30}" "$LOG" ;;
  *) echo "usage: $0 {start|stop|status|log}"; exit 1 ;;
esac
