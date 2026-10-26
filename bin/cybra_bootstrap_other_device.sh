#!/data/data/com.termux/files/usr/bin/bash
# BOOTSTRAP OTHER DEVICE — pkg + clone + deploy + 160 items + bar contracts + verify
# Запуск: bash bin/cybra_bootstrap_other_device.sh [TAG]
set -uo pipefail
REPO="${CYBRA_REPO:-https://github.com/Lubnysash1980/cybra-node.git}"
TAG="${1:-main}"
BASE="$HOME/CYBRA"
TS=$(date +%Y%m%d_%H%M%S)
LOG="$BASE/logs/bootstrap_$TS.log"
mkdir -p "$BASE/logs" 2>/dev/null
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
ok(){ log "  ✅ $*"; }
warn(){ log "  ⚠️  $*"; }
err(){ log "  ❌ $*"; }

log "═══ BOOTSTRAP OTHER DEVICE ($TS) ═══"
log "  repo: $REPO  tag: $TAG"

# ─── 1. pkg ───
log "── 1. install pkg ──"
pkg update -y >/dev/null 2>&1 || true
for p in git python nodejs redis nano curl openssh jq tar coreutils; do
  dpkg -s "$p" >/dev/null 2>&1 || pkg install -y "$p" >/dev/null 2>&1 || true
done
command -v pm2 >/dev/null || npm install -g pm2 >/dev/null 2>&1
ok "pkg ready"

# ─── 2. clone / pull ───
log "── 2. clone/pull ──"
if [ -d "$BASE/.git" ]; then
  cd "$BASE"
  git fetch origin >/dev/null 2>&1
  git checkout "$TAG" 2>/dev/null || git pull origin main >/dev/null 2>&1
  ok "pulled to $TAG"
else
  git clone "$REPO" "$BASE" >/dev/null 2>&1
  cd "$BASE"
  [ "$TAG" != "main" ] && git checkout "$TAG" >/dev/null 2>&1
  ok "cloned"
fi
cd "$BASE"

# git identity fallback
git config user.email >/dev/null 2>&1 || git config user.email "node@cybra.local"
git config user.name  >/dev/null 2>&1 || git config user.name  "cybra-node"

# ─── 3. redis ───
log "── 3. redis ──"
redis-cli ping 2>/dev/null | grep -q PONG || {
  pm2 start redis-server --name redis -- --daemonize no >/dev/null 2>&1
  sleep 3
}
redis-cli ping 2>/dev/null | grep -q PONG && ok "PONG" || { err "redis down"; exit 1; }

# ─── 4. python deps ───
log "── 4. python deps ──"
pip install redis -q 2>/dev/null || true
python3 -c "import redis" 2>/dev/null && ok "redis-py" || warn "redis-py missing"

# ─── 5. main files check ───
log "── 5. files ──"
MISSING=0
for f in parliament_executor_v6.py parliament_menu_worker.sh \
         bin/cybra_menu_autorobot.py bin/cybra_evo_controller.py \
         bin/cybra_autopilot.py bin/cybra_hidl_worker.py bin/cybra_hidl_notifier.py \
         bin/cybra_taxi_events.py bin/cybra_health.sh; do
  [ -f "$f" ] || { warn "missing: $f"; MISSING=$((MISSING+1)); }
done
[ "$MISSING" -eq 0 ] && ok "все на місці" || warn "$MISSING файлів бракує"

# ─── 6. regenerate 160 modules if needed ───
log "── 6. 160 modules ──"
MOD_COUNT=$(ls -d modules/module_* 2>/dev/null | grep -cE 'module_[0-9]' || echo 0)
if [ "$MOD_COUNT" -lt 160 ] && [ -f bin/cybra_gen.py ]; then
  python3 bin/cybra_gen.py 2>&1 | tail -3
else
  ok "modules: $MOD_COUNT"
fi

# ─── 7. menu wire check ───
log "── 7. menu wire ──"
MENU="modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
if [ -f "$MENU" ]; then
  WIRES=$(grep -cE '^\s*[0-9]+\)\s' "$MENU" 2>/dev/null || echo 0)
  if [ "$WIRES" -lt 160 ] && [ -f bin/cybra_gen.py ]; then
    python3 bin/cybra_gen.py >/dev/null 2>&1
    WIRES=$(grep -cE '^\s*[0-9]+\)\s' "$MENU" 2>/dev/null || echo 0)
  fi
  ok "menu: $WIRES wires"
else
  warn "menu missing"
fi

# ─── 8. PM2 processes ───
log "── 8. PM2 ──"
redis-cli hset cybra:executor:mapping write_module parliament_write_module_handler.sh >/dev/null 2>&1
start_pm2() {
  local name="$1" script="$2" interp="$3"; shift 3
  pm2 describe "$name" >/dev/null 2>&1 && { pm2 restart "$name" >/dev/null 2>&1; return; }
  [ -f "$script" ] && pm2 start "$script" --name "$name" --interpreter "$interp" "$@" >/dev/null 2>&1
}
start_pm2 parliament       "$BASE/parliament_executor_v6.py"                 python3
start_pm2 menu-worker      "$BASE/parliament_menu_worker.sh"                 bash
start_pm2 menu-autorobot   "$BASE/bin/cybra_menu_autorobot.py"               python3 -- loop 120
start_pm2 cybra-evo-ctrl   "$BASE/bin/cybra_evo_controller.py"               python3 -- loop 600
start_pm2 cybra-autopilot  "$BASE/bin/cybra_autopilot.py"                    python3 -- loop 900
start_pm2 hidl-worker      "$BASE/bin/cybra_hidl_worker.py"                  python3
start_pm2 hidl-notifier    "$BASE/bin/cybra_hidl_notifier.py"                python3
start_pm2 taxi-events      "$BASE/bin/cybra_taxi_events.py"                  python3
start_pm2 cybra-api        "$BASE/api/run.sh"                                bash
pm2 save >/dev/null 2>&1
PM2_COUNT=$(pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(sum(1 for p in d if p['pm2_env']['status']=='online'))" 2>/dev/null || echo 0)
ok "PM2 online: $PM2_COUNT"

# ─── 9. bar menu 160 contracts ───
log "── 9. 160 bar menu contracts ──"
if [ -f bin/cybra_bar_menu_160_contracts.sh ]; then
  bash bin/cybra_bar_menu_160_contracts.sh 2>&1 | tail -15
else
  warn "bin/cybra_bar_menu_160_contracts.sh missing"
fi

# ─── 10. verify ───
log "── 10. verify ──"
sleep 3
if [ -f bin/cybra_state_100.sh ]; then
  bash bin/cybra_state_100.sh 2>&1 | tail -15
fi
if [ -f bin/cybra_health.sh ]; then
  bash bin/cybra_health.sh 2>&1 | tail -5
fi

# ─── 11. git push ───
log "── 11. git push ──"
git add -A 2>/dev/null
git commit -m "bootstrap: other device ready ($TS)" 2>&1 | head -1
git push origin main 2>&1 | tail -2

log ""
log "═══ BOOTSTRAP DONE ═══"
log "  log:    $LOG"
log "  device: $(hostname)"
log "  HEAD:   $(git rev-parse --short HEAD)"
log ""
log "  next:"
log "    cybra                              # меню 160"
log "    bash bin/cybra_state_100.sh        # 100% gate"
log "    redis-cli hlen cybra:bar:menu      # 160 contracts"
log "    ~/CYBRA/taxi_premium               # taxi menu"
