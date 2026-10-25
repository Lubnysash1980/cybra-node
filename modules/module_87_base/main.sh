#!/data/data/com.termux/files/usr/bin/bash
# module_087 — rich (evo upgraded)
# generated: 2026-10-25T07:09:57.556178+00:00
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_087.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
trap 'log "ERR line $LINENO rc=$?"' ERR

show_git() {
  echo "── git ──"
  git --no-pager log -1 --format='  %h %s (%cr)' 2>/dev/null | head -1
  echo "  changes: $(git status --porcelain 2>/dev/null | wc -l)"
}
show_redis() {
  echo "── redis ──"
  redis-cli ping 2>/dev/null | sed 's/^/  /' || echo "  DOWN"
  redis-cli dbsize 2>/dev/null | awk '{print "  keys: "$1}'
}
show_system() {
  echo "── system ──"
  free -m 2>/dev/null | awk '/Mem:/{printf "  RAM: %d/%d MB (%d%%)\\n",$3,$2,$3/$2*100}'
  df -h /data 2>/dev/null | awk 'NR==2{printf "  disk: %s/%s (%s)\\n",$3,$2,$5}'
}
show_pm2() {
  echo "── pm2 ──"
  pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    on=sum(1 for p in d if p['pm2_env']['status']=='online')
    print(f'  online: {on}/{len(d)}')
except: print('  n/a')
" 2>/dev/null || echo "  n/a"
}
show_log() {
  echo "── log (last 3) ──"
  tail -3 "$LOG" 2>/dev/null | sed 's/^/  /' || echo "  empty"
}

main() {
  log "START module_087 args=$#"
  echo "════════ module_087 ════════"
  case "${1:-all}" in
    git) show_git ;;
    redis) show_redis ;;
    sys|system) show_system ;;
    pm2) show_pm2 ;;
    log) show_log ;;
    all|*)
      show_git; echo ""
      show_redis; echo ""
      show_system; echo ""
      show_pm2; echo ""
      show_log ;;
  esac
  log "END module_087"
  read -r -p "Enter..." _ 2>/dev/null || true
}
main "$@"
