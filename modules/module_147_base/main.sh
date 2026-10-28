#!/data/data/com.termux/files/usr/bin/bash
# module_147 — premium (evo v2)
# generated: 2026-10-25T07:19:17.847639+00:00
set -euo pipefail
CYBRA="${CYBRA:-$HOME/CYBRA}"
LOG="$CYBRA/logs/module_147.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
err() { log "ERR: $*"; echo "  ❌ $*" >&2; return 1; }
trap 'err "line $LINENO rc=$?"' ERR

cmd_git() {
  echo "── git ──"
  git --no-pager log -1 --format='  %h %s (%cr)' 2>/dev/null | head -1
  echo "  changes: $(git -C "$CYBRA" status --porcelain 2>/dev/null | wc -l)"
  echo "  branch:  $(git -C "$CYBRA" rev-parse --abbrev-ref HEAD 2>/dev/null)"
}

cmd_redis() {
  echo "── redis ──"
  local pong=$(redis-cli ping 2>/dev/null || echo "DOWN")
  echo "  $pong"
  echo "  keys: $(redis-cli dbsize 2>/dev/null || echo 0)"
  echo "  queue: $(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0)"
}

cmd_system() {
  echo "── system ──"
  free -m 2>/dev/null | awk '/Mem:/{printf "  RAM: %d/%d MB (%d%%)\\n",$3,$2,$3/$2*100}'
  df -h /data 2>/dev/null | awk 'NR==2{printf "  disk: %s/%s (%s)\\n",$3,$2,$5}'
  echo "  load: $(cat /proc/loadavg 2>/dev/null | cut -d' ' -f1-3)"
}

cmd_pm2() {
  echo "── pm2 ──"
  pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    on=[p['name'] for p in d if p['pm2_env']['status']=='online']
    print(f'  online: {len(on)}/{len(d)}')
    for p in on[:5]: print(f'    ✓ {p}')
except: print('  n/a')
"
}

cmd_log() {
  echo "── log ──"
  tail -5 "$LOG" 2>/dev/null | sed 's/^/  /' || echo "  (empty)"
}

cmd_health() {
  echo "── health ──"
  echo "  bash: $(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  echo "  python: $(python3 --version 2>&1 | awk '{print $2}')"
  echo "  node: $(node --version 2>/dev/null || echo 'n/a')"
  echo "  redis-cli: $(command -v redis-cli >/dev/null && echo yes || echo no)"
}

usage() {
  cat <<USAGE
usage: $0 [command]
  git | redis | sys | pm2 | log | health | all
USAGE
}

main() {
  local cmd="${1:-all}"
  log "START module_147 cmd=$cmd"
  echo "════════ module_147 ════════"
  case "$cmd" in
    git) cmd_git ;;
    redis) cmd_redis ;;
    sys|system) cmd_system ;;
    pm2) cmd_pm2 ;;
    log) cmd_log ;;
    health) cmd_health ;;
    all)
      cmd_git; echo ""
      cmd_redis; echo ""
      cmd_system; echo ""
      cmd_pm2; echo ""
      cmd_log ;;
    -h|--help|help) usage ;;
    *) usage; return 1 ;;
  esac
  log "END module_147"
  read -r -p "Enter..." _ 2>/dev/null || true
}

main "$@"
