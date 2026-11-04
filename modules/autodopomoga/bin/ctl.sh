#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
PIDFILE="$CYBRA/.cache/autodopomoga.pid"
LOG="$CYBRA/logs/autodopomoga.log"

case "${1:-status}" in
    start)
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
            echo "already running pid=$(cat "$PIDFILE")"; exit 0
        fi
        cd "$CYBRA"
        setsid nohup "$MOD/bin/autodopomoga.sh" >/dev/null 2>&1 < /dev/null &
        sleep 2
        [ -f "$PIDFILE" ] && echo "✓ started pid=$(cat "$PIDFILE")" || { echo "✗ failed — $LOG"; exit 1; }
        ;;
    stop)
        [ -f "$PIDFILE" ] && { P=$(cat "$PIDFILE"); kill "$P" 2>/dev/null; sleep 1; kill -9 "$P" 2>/dev/null; rm -f "$PIDFILE"; echo "stopped pid=$P"; } || echo "not running"
        ;;
    restart) "$0" stop; sleep 1; "$0" start ;;
    status)
        echo "── autodopomoga ──"
        if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
            P=$(cat "$PIDFILE")
            echo "RUNNING pid=$P uptime=$(ps -o etime= -p "$P" 2>/dev/null | tr -d ' ')"
        else echo "STOPPED"; fi
        echo ""
        echo "── current deviation ──"
        "$MOD/bin/verify.sh"
        echo ""
        echo "── attempts ──"
        jq . "$MOD/state/attempts.json" 2>/dev/null || echo '{}'
        echo ""
        echo "── last 8 log ──"
        tail -8 "$LOG" 2>/dev/null || echo "(no log)"
        ;;
    log) tail -n "${2:-30}" "$LOG" ;;
    verify) "$MOD/bin/verify.sh" ;;
    repair) shift; "$MOD/bin/repair.sh" "$@" ;;
    *) echo "usage: ctl.sh {start|stop|restart|status|log [N]|verify|repair <comp> <n>}"; exit 1 ;;
esac
