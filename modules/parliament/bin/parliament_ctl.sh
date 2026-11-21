#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
PIDFILE="$CYBRA/.cache/parliament-auto.pid"
LOG="$CYBRA/logs/parliament-auto.log"

case "${1:-status}" in
  start)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
      echo "already running pid=$(cat "$PIDFILE")"; exit 0
    fi
    cd "$CYBRA"
    setsid nohup "$MOD/bin/propose_auto.sh" >/dev/null 2>&1 < /dev/null &
    sleep 2
    [ -f "$PIDFILE" ] && echo "✓ started pid=$(cat "$PIDFILE")" || { echo "✗ failed — check $LOG"; exit 1; }
    ;;
  stop)
    if [ -f "$PIDFILE" ]; then
      P=$(cat "$PIDFILE"); kill "$P" 2>/dev/null; sleep 1; kill -9 "$P" 2>/dev/null
      rm -f "$PIDFILE"; echo "stopped pid=$P"
    else echo "not running"; fi
    ;;
  restart) "$0" stop; sleep 1; "$0" start ;;
  status)
    echo "── propose_auto daemon ──"
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
      P=$(cat "$PIDFILE")
      echo "RUNNING pid=$P uptime=$(ps -o etime= -p "$P" 2>/dev/null | tr -d ' ')"
    else
      echo "STOPPED"
    fi
    echo ""
    echo "── recent rollback events ──"
    [ -s "$MOD/state/.rollback-events.log" ] && tail -5 "$MOD/state/.rollback-events.log" || echo "(none)"
    echo ""
    echo "── last auto proposal ──"
    if [ -s "$MOD/state/.last-auto-proposal.ts" ]; then
      date -d "@$(cat "$MOD/state/.last-auto-proposal.ts")" 2>/dev/null || cat "$MOD/state/.last-auto-proposal.ts"
    else echo "(never)"; fi
    echo ""
    "$MOD/bin/parliament.sh" status
    ;;
  log) tail -n "${2:-30}" "$LOG" ;;
  baseline) "$MOD/bin/baseline.sh" ;;
  sanity)   "$MOD/bin/sanity.sh" ;;
  *) echo "usage: parliament_ctl.sh {start|stop|restart|status|log [N]|baseline|sanity}"; exit 1 ;;
esac
