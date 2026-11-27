#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${CYBRA_ROOT:-$HOME/CYBRA}"
HERE="$(cd "$(dirname "$0")" && pwd)"
PORT="${CYBRA_EVOLUTION_PORT:-8765}"
case "${1:-start}" in
  start)
    if curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
      echo "CYBRA Evolution Dashboard already running: http://127.0.0.1:$PORT/"
      exit 0
    fi
    export CYBRA_ROOT="$ROOT" CYBRA_EVOLUTION_PORT="$PORT"
    nohup python "$HERE/server.py" >"$ROOT/logs/evolution-dashboard.log" 2>&1 &
    echo $! >"$ROOT/state/evolution-dashboard.pid"
    sleep 1
    curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null
    echo "STARTED: http://127.0.0.1:$PORT/"
    echo "ROOT: $ROOT"
    echo "MODE: read-only; automatic restart disabled"
    ;;
  status)
    curl -fsS "http://127.0.0.1:$PORT/api/state" | python -m json.tool
    ;;
  logs)
    tail -n 80 "$ROOT/logs/evolution-dashboard.log"
    ;;
  stop)
    PIDFILE="$ROOT/state/evolution-dashboard.pid"
    if [ -f "$PIDFILE" ]; then
      PID="$(cat "$PIDFILE")"
      if kill -0 "$PID" 2>/dev/null; then kill "$PID"; echo "STOPPED PID=$PID"; else echo "Not running"; fi
      rm -f "$PIDFILE"
    else
      echo "PID file not found"
    fi
    ;;
  *)
    echo "Usage: $0 {start|status|logs|stop}"
    exit 2
    ;;
esac
