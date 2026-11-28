#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="${CYBRA_ROOT:-$(cd "$HERE/.." && pwd)}"
PORT="${CYBRA_EVOLUTION_PORT:-8765}"
mkdir -p "$ROOT/logs" "$ROOT/state"
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
    if ! curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null; then
      echo "START FAILED — inspect: $ROOT/logs/evolution-dashboard.log"
      exit 1
    fi
    echo "STARTED: http://127.0.0.1:$PORT/"
    echo "ROOT: $ROOT"
    echo "MODE: read-only; automatic restart disabled"
    ;;
  status)
    curl -fsS "http://127.0.0.1:$PORT/api/state" | python -c '
import json,sys
d=json.load(sys.stdin)
e=d["evolution_pct"]
color="GREEN" if e>=3 else ("RED" if e<0 else "YELLOW")
p=d["pm2"]
pm2=(str(p["online"])+" online / "+str(p["total"])) if p["available"] else "not connected"
print("CYBRA EVOLUTION STATUS")
print("Evolution : {:+.3f}% [{}]".format(e,color))
print("Modules   : {} / {}".format(d["modules_detected"],d["module_target"]))
print("Creation  : {:.2f}%".format(d["auto_creation_pct"]))
print("Files     : {} (new {}, changed {})".format(d["files"],d["new_files"],d["changed_files"]))
print("Health    : NOT MEASURED (module checks not connected)")
print("PM2       : "+pm2)
print("Restart   : MANUAL ONLY")
print("Root      : "+d["root"])
'
    ;;
  json)
    curl -fsS "http://127.0.0.1:$PORT/api/state" | python -m json.tool
    ;;
  logs)
    tail -n 80 "$ROOT/logs/evolution-dashboard.log"
    ;;
  stop)
    PIDFILE="$ROOT/state/evolution-dashboard.pid"
    if [ -f "$PIDFILE" ]; then
      PID="$(cat "$PIDFILE")"
      if kill -0 "$PID" 2>/dev/null; then
        if [ -r "/proc/$PID/cmdline" ] && tr '\0' ' ' < "/proc/$PID/cmdline" | grep -Fq "$HERE/server.py"; then
          kill "$PID"
          echo "STOPPED DASHBOARD PID=$PID"
        else
          echo "REFUSED: PID file does not point to this dashboard process"
        fi
      else
        echo "Not running"
      fi
      rm -f "$PIDFILE"
    else
      echo "PID file not found"
    fi
    ;;
  *)
    echo "Usage: $0 {start|status|json|logs|stop}"
    exit 2
    ;;
esac
