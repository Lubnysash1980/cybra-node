#!/data/data/com.termux/files/usr/bin/bash
# CYBRA DEPLOY — idempotent, без bug MENU unbound
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || { echo "FATAL: no $CYBRA"; exit 1; }
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
TS=$(date +%Y%m%d_%H%M%S); LOG="$CYBRA/logs/deploy_$TS.log"
FORCE=0; NO_PM2=0; VERIFY=0
for a in "$@"; do case "$a" in
  --force) FORCE=1 ;; --no-pm2) NO_PM2=1 ;; --verify-only) VERIFY=1 ;;
esac; done
mkdir -p "$CYBRA/logs" "$CYBRA/state" "$CYBRA/bin" "$CYBRA/parliament_core/tasks"
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
log "═══ CYBRA DEPLOY ($TS) force=$FORCE pm2=$([ $NO_PM2 -eq 0 ] && echo on || echo off) ═══"

if [ $VERIFY -eq 0 ]; then
  log "── deps ──"
  command -v redis-cli >/dev/null || pkg install -y redis >/dev/null 2>&1
  python3 -c "import redis" 2>/dev/null || pip install redis -q 2>/dev/null
  python3 -c "import redis" 2>/dev/null && log "  ✅ redis-py" || { log "  ❌ redis-py"; exit 1; }

  log "── redis ──"
  redis-cli ping 2>/dev/null | grep -q PONG || {
    pm2 start redis-server --name redis -- --daemonize no 2>/dev/null; sleep 3; }
  redis-cli ping 2>/dev/null | grep -q PONG && log "  ✅ PONG" || { log "  ❌"; exit 1; }

  log "── mapping ──"
  redis-cli hset cybra:executor:mapping write_module parliament_write_module_handler.sh >/dev/null
  log "  ✅"
fi

if [ $VERIFY -eq 0 ] && [ $NO_PM2 -eq 0 ]; then
  log "── pm2 ──"
  up() {
    local n="$1" s="$2" i="$3"; shift 3
    [ -f "$s" ] || return 0
    pm2 describe "$n" >/dev/null 2>&1 && pm2 restart "$n" >/dev/null 2>&1 \
      || pm2 start "$s" --name "$n" --interpreter "$i" "$@" >/dev/null 2>&1
  }
  up parliament       "$CYBRA/parliament_executor_v6.py"        python3
  up menu-worker      "$CYBRA/parliament_menu_worker.sh"        bash
  up menu-autorobot   "$CYBRA/bin/cybra_menu_autorobot.py"      python3 -- loop 120
  up cybra-evo-ctrl   "$CYBRA/bin/cybra_evo_controller.py"      python3 -- loop 600
  pm2 save >/dev/null 2>&1
  log "  ✅"
fi

log "── verify ──"
sleep 2; echo ""
log "═══ SUMMARY ═══"
log "  log:     $LOG"
log "  pm2:"
pm2 list 2>/dev/null | grep -E 'parliament|menu-worker|autorobot|evo-ctrl|redis' | sed 's/^/    /'
log "  redis:   $(redis-cli ping 2>/dev/null || echo down)"
log "  queue:   $(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0)"
log "  failed:  $(redis-cli llen cybra:parliament:failed 2>/dev/null || echo 0)"
log "  results: $(redis-cli llen cybra:parliament:results 2>/dev/null || echo 0)"
log "  menu:    $(grep -cE '^\s*[0-9]+\)\s' "$MENU" 2>/dev/null || echo 0) handlers"
if [ -f "$CYBRA/bin/cybra_menu_autorobot.py" ]; then
  log "  autorobot: $(python3 "$CYBRA/bin/cybra_menu_autorobot.py" status 2>/dev/null | head -1)"
fi
if [ -f "$CYBRA/bin/cybra_evo_controller.py" ]; then
  log "  evo:     $(python3 "$CYBRA/bin/cybra_evo_controller.py" status 2>/dev/null | grep -E 'avg:' | tr '\n' ' ')"
fi
log "  next:    cybra"
