#!/data/data/com.termux/files/usr/bin/bash
# CYBRA DEPLOY на новому пристрої: clone → install → start
# Usage: bash cybra_deploy_device.sh [git-repo-url] [tag]
set -uo pipefail
REPO="${1:-https://github.com/Lubnysash1980/cybra-node.git}"
TAG="${2:-main}"
BASE="$HOME/CYBRA"

echo "═══ DEPLOY → $BASE ═══"
echo "  repo: $REPO"
echo "  tag:  $TAG"

# 1. pkg
echo "── pkg ──"
pkg update -y >/dev/null 2>&1 || true
for p in git python nodejs-lts redis nano curl openssh jq; do
  command -v "${p%%-*}" >/dev/null 2>&1 || pkg install -y "$p" >/dev/null 2>&1 || true
done
command -v pm2 >/dev/null || npm install -g pm2 >/dev/null 2>&1
echo "  ✅ pkg ready"

# 2. clone
if [ -d "$BASE/.git" ]; then
  echo "── existing $BASE, pulling $TAG ──"
  cd "$BASE"; git fetch origin; git checkout "$TAG" 2>/dev/null || git pull origin main
else
  echo "── cloning ──"
  git clone "$REPO" "$BASE"
  cd "$BASE"; [ "$TAG" != "main" ] && git checkout "$TAG" || true
fi
cd "$BASE"

# 3. python deps
pip install redis -q 2>/dev/null || true
python3 -c "import redis" 2>/dev/null && echo "  ✅ redis-py"

# 4. redis
pm2 describe redis >/dev/null 2>&1 || pm2 start redis-server --name redis -- --daemonize no
sleep 3
redis-cli ping | grep -q PONG && echo "  ✅ redis PONG"

# 5. mapping (зник після нового redis)
redis-cli hset cybra:executor:mapping write_module parliament_write_module_handler.sh >/dev/null 2>&1 || true

# 6. core processes
for p in parliament menu-worker menu-autorobot cybra-evo-ctrl cybra-autopilot hidl-worker hidl-notifier; do
  pm2 describe "$p" >/dev/null 2>&1 && continue
  case "$p" in
    parliament)       [ -f parliament_executor_v6.py ] && pm2 start parliament_executor_v6.py --name parliament --interpreter python3 ;;
    menu-worker)      [ -f parliament_menu_worker.sh ] && pm2 start parliament_menu_worker.sh --name menu-worker --interpreter bash ;;
    menu-autorobot)   [ -f bin/cybra_menu_autorobot.py ] && pm2 start bin/cybra_menu_autorobot.py --name menu-autorobot --interpreter python3 -- loop 120 ;;
    cybra-evo-ctrl)   [ -f bin/cybra_evo_controller.py ] && pm2 start bin/cybra_evo_controller.py --name cybra-evo-ctrl --interpreter python3 -- loop 600 ;;
    cybra-autopilot)  [ -f bin/cybra_autopilot.py ] && pm2 start bin/cybra_autopilot.py --name cybra-autopilot --interpreter python3 -- loop 900 ;;
    hidl-worker)      [ -f bin/cybra_hidl_worker.py ] && pm2 start bin/cybra_hidl_worker.py --name hidl-worker --interpreter python3 ;;
    hidl-notifier)    [ -f bin/cybra_hidl_notifier.py ] && pm2 start bin/cybra_hidl_notifier.py --name hidl-notifier --interpreter python3 ;;
  esac
done
pm2 save >/dev/null 2>&1

# 7. verify
echo ""
echo "═══ VERIFY ═══"
bash bin/cybra_health.sh 2>/dev/null | tail -5

echo ""
echo "✅ DONE"
echo "   next: cybra  (меню 160)"
echo "   OR:   ~/CYBRA/bin/cybra_notify.sh bar"
