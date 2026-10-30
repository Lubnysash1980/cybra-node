#!/data/data/com.termux/files/usr/bin/bash
# TUI [161] Taxi Events  (taxi)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"
mkdir -p "$CYBRA/logs" "$CYBRA/state" 2>/dev/null
ACTION="${1:-status}"
if [ "$ACTION" = "status" ] || [ "$ACTION" = "list" ]; then
  echo "════ [161] Taxi Events (taxi) ════"
  shift 2>/dev/null || true
  echo "  pending: $(redis-cli llen cybra:taxi:events 2>/dev/null || echo 0)"
elif [ "$ACTION" = "help" ] || [ "$ACTION" = "--help" ] || [ "$ACTION" = "-h" ]; then
  echo "Usage: $0 [status|run|help] [args]"
  echo "TUI point [161] Taxi Events (taxi)"
elif [ "$ACTION" = "run" ]; then
  shift 2>/dev/null || true
  # taxi: подія в чергу + перевірка worker
if [ -z "${1:-}" ]; then
  echo "taxi events: $(redis-cli llen cybra:taxi:events 2>/dev/null || echo 0) pending"
  echo "worker: $(pm2 jlist 2>/dev/null | grep -c taxi-events || echo 0)"
else
  redis-cli lpush "cybra:taxi:events" "$1" >/dev/null && echo "queued: $1"
fi
else
  # taxi: подія в чергу + перевірка worker
if [ -z "${1:-}" ]; then
  echo "taxi events: $(redis-cli llen cybra:taxi:events 2>/dev/null || echo 0) pending"
  echo "worker: $(pm2 jlist 2>/dev/null | grep -c taxi-events || echo 0)"
else
  redis-cli lpush "cybra:taxi:events" "$1" >/dev/null && echo "queued: $1"
fi
fi
