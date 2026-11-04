#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
PIDFILE="$CYBRA/.cache/stats.pid"
LOG="$CYBRA/logs/stats.log"
case "${1:-status}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
      echo "already running pid=$(cat "$PIDFILE")"; exit 0
    fi
    cd "$CYBRA"
    setsid nohup "$MOD/bin/daemon.sh" >/dev/null 2>&1 < /dev/null &
    sleep 2
    [ -f "$PIDFILE" ] && echo "✓ started pid=$(cat "$PIDFILE")" || { echo "✗ failed — $LOG"; exit 1; }
    ;;
  stop)
    [ -f "$PIDFILE" ] && { P=$(cat "$PIDFILE"); kill "$P" 2>/dev/null; sleep 1; kill -9 "$P" 2>/dev/null; rm -f "$PIDFILE"; echo "stopped pid=$P"; } || echo "not running"
    ;;
  restart) "$0" stop; sleep 1; "$0" start ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
      P=$(cat "$PIDFILE"); echo "RUNNING pid=$P uptime=$(ps -o etime= -p "$P" 2>/dev/null | tr -d ' ')"
    else echo "STOPPED"; fi
    echo ""
    "$MOD/bin/report.sh" full
    ;;
  log) grep -E '^\[20' "$LOG" 2>/dev/null | tail -n "${2:-30}" ;;
  collect) "$MOD/bin/collect.sh" | jq '{ts,window_sec,window_cut}' ;;
  analyze) "$MOD/bin/analyze.sh" | jq . ;;
  *) echo "usage: ctl.sh {start|stop|restart|status|log [N]|collect|analyze}"; exit 1 ;;
esac
