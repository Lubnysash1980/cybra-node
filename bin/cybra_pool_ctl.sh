#!/data/data/com.termux/files/usr/bin/bash
set -u
case "${1:-status}" in
  start) pm2 delete cybra-pool 2>/dev/null; pm2 start bin/cybra_pool_worker.js --name "cybra-pool" --watch --ignore-watch="node_modules logs dumps .cache"; pm2 save; echo "✓ started" ;;
  stop) pm2 stop cybra-pool; pm2 delete cybra-pool; echo "stopped" ;;
  restart) pm2 restart cybra-pool; echo "restarted" ;;
  status) pm2 describe cybra-pool | grep -E "status|uptime|restarts" || echo "not running" ;;
  log) pm2 logs cybra-pool --lines "${2:-30}" --nostream ;;
  *) echo "usage: $0 {start|stop|restart|status|log [N]}"; exit 1 ;;
esac
