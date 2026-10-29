#!/data/data/com.termux/files/usr/bin/bash
# cybra_orchestrator.sh — test | heal | up | watch | debug | logic | auto
set -u
cd "$HOME/CYBRA" || exit 1
LOG=logs/orchestrator
mkdir -p "$LOG"
ts(){ date '+%Y-%m-%d %H:%M:%S'; }
say(){ echo "[$(ts)] $*" | tee -a "$LOG/run.log"; }

# ---- TEST: перевірка що все на місці ----
do_test(){
  say "=== TEST ==="
  local fail=0
  for f in cybra_node.sh launch_kibra_internal_mainnet_and_test.sh \
           cybra_autoheal.sh cybra_self_healing_supervisor.sh cybra_checkpoint.sh; do
    [ -f "$f" ] && say "  ✅ $f" || { say "  ❌ $f"; fail=1; }
  done
  bash cybra_checkpoint.sh verify >>"$LOG/test.log" 2>&1
  local v=$?
  [ $v -eq 0 ] && say "  ✅ 100% verify" || { say "  ❌ verify fail"; fail=1; }
  [ "$(redis-cli ping 2>/dev/null)" = "PONG" ] && say "  ✅ redis" || { say "  ❌ redis"; fail=1; }
  say "  --- результат: $([ $fail -eq 0 ] && echo OK || echo FAIL) ---"
  return $fail
}

# ---- HEAL: запустити існуючі автолікувачі ----
do_heal(){
  say "=== HEAL ==="
  pkill -f cybra_autoheal.sh 2>/dev/null || true
  nohup bash cybra_autoheal.sh >>"$LOG/heal.log" 2>&1 &
  say "  autoheal pid=$!"
  if [ -f cybra_self_healing_supervisor.sh ]; then
    pkill -f cybra_self_healing_supervisor.sh 2>/dev/null || true
    nohup bash cybra_self_healing_supervisor.sh >>"$LOG/supervisor.log" 2>&1 &
    say "  supervisor pid=$!"
  fi
}

# ---- UP: підняти ноду + pm2, потім verify ----
do_up(){
  say "=== UP ==="
  # 1. redis
  redis-cli ping >/dev/null 2>&1 || { say "  start redis"; pm2 start redis 2>/dev/null; sleep 2; }
  # 2. pm2 resurrect
  pm2 resurrect >>"$LOG/pm2.log" 2>&1
  sleep 3
  # 3. нода — через існуючі скрипти
  if pgrep -f cybra_node >/dev/null; then say "  node вже живий"
  else
    say "  launch cybra_node.sh"
    nohup bash cybra_node.sh >>"$LOG/node.log" 2>&1 &
    sleep 8
  fi
  # 4. checkpoint verify
  bash cybra_checkpoint.sh verify >>"$LOG/up.log" 2>&1
  say "  verify: $?"
}

# ---- WATCH: цикл verify+heal кожні N сек ----
do_watch(){
  local iv="${1:-120}"
  say "=== WATCH every ${iv}s ==="
  while true; do
    if ! bash cybra_checkpoint.sh verify >/dev/null 2>&1; then
      say "verify fail → heal"
      do_heal
      sleep 10
      do_up
    fi
    echo "[$(ts)] tick ok" >>"$LOG/watch.log"
    sleep "$iv"
  done
}

# ---- DEBUG: зібрати діагностику в один файл ----
do_debug(){
  local out="runtime/debug_$(date +%Y%m%d_%H%M%S).txt"
  mkdir -p runtime
  {
    echo "# DEBUG $(ts)"
    echo "## PM2"; pm2 list
    echo "## RAM"; free -m
    echo "## REDIS"; redis-cli ping; redis-cli LLEN cybra:parliament:queue 2>/dev/null
    echo "## GIT"; git log -1 --oneline; git status -sb | head -5
    echo "## TAGS pct100"; git tag -l 'pct100-*'
    echo "## PM2 ERRORS"; pm2 logs --nostream --err --lines 30 2>/dev/null | tail -40
    echo "## NODE LOG"; tail -30 "$LOG/node.log" 2>/dev/null
    echo "## ORCH LOG"; tail -30 "$LOG/run.log" 2>/dev/null
  } > "$out"
  say "debug → $out"
}

# ---- LOGIC: перевірка логічної консистентності ----
do_logic(){
  say "=== LOGIC ==="
  local fail=0
  # 1. git HEAD має бути на pct100-тезі
  local head tag
  head=$(git rev-parse HEAD)
  tag=$(git tag -l 'pct100-*' | sort | tail -1)
  [ -z "$tag" ] && { say "  ❌ нема pct100-тегу"; fail=1; }
  [ -n "$tag" ] && [ "$(git rev-list -n1 "$tag")" != "$head" ] && { say "  ⚠️ HEAD != $tag (можливо еволюція після точки)"; }
  # 2. redis-черги не ростуть безкінечно
  local q failed
  q=$(redis-cli LLEN cybra:parliament:queue 2>/dev/null || echo 0)
  failed=$(redis-cli LLEN cybra:parliament:failed 2>/dev/null || echo 0)
  [ "$q" -gt 100 ] && { say "  ❌ queue=$q > 100 (застрягло)"; fail=1; }
  [ "$failed" -gt 50 ] && { say "  ⚠️ failed=$failed — можливо хендлери не працюють"; }
  say "  queue=$q failed=$failed"
  # 3. pm2 errored не більше 2
  local err
  err=$(pm2 jlist 2>/dev/null | grep -o '"status":"errored"' | wc -l)
  [ "$err" -gt 2 ] && { say "  ❌ errored=$err > 2"; fail=1; } || say "  ✅ errored=$err"
  # 4. RAM < 90%
  local pct
  pct=$(free -m | awk 'NR==2{print int($3*100/$2)}')
  [ "$pct" -ge 90 ] && { say "  ❌ RAM $pct%"; fail=1; } || say "  ✅ RAM $pct%"
  say "  --- $([ $fail -eq 0 ] && echo LOGIC_OK || echo LOGIC_FAIL) ---"
  return $fail
}

# ---- AUTO: test → up → heal → watch (як 2 сервіси) ----
do_auto(){
  say "=== AUTO (2 services: watch + heal) ==="
  do_test || { say "test fail — стоп"; exit 1; }
  do_up
  sleep 3
  # Service 1: watchdog
  pkill -f "cybra_orchestrator.sh watch" 2>/dev/null || true
  nohup bash "$0" watch 120 >>"$LOG/watch_loop.log" 2>&1 &
  say "  service-1 (watch) pid=$!"
  # Service 2: heal loop
  do_heal
  say "  service-2 (heal) launched"
  say "=== AUTO READY ==="
}

case "${1:-help}" in
  test)   do_test ;;
  heal)   do_heal ;;
  up)     do_up ;;
  watch)  do_watch "${2:-120}" ;;
  debug)  do_debug ;;
  logic)  do_logic ;;
  auto)   do_auto ;;
  *) echo "Usage: bash cybra_orchestrator.sh test|heal|up|watch|debug|logic|auto" ;;
esac
