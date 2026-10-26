#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
TAG="${1:-main}"; BASE="$HOME/CYBRA"
echo "═══ BOOTSTRAP ($TAG) ═══"
[ -d "$BASE/.git" ] || git clone "${CYBRA_REPO:-https://github.com/Lubnysash1980/cybra-node.git}" "$BASE"
cd "$BASE"
git fetch origin; git checkout "$TAG" 2>/dev/null || git pull origin main
pkg update -y >/dev/null 2>&1 || true
for p in git python nodejs redis nano curl openssh jq; do dpkg -s "$p" >/dev/null 2>&1 || pkg install -y "$p" >/dev/null 2>&1; done
command -v pm2 >/dev/null || npm install -g pm2 >/dev/null 2>&1
pip install redis -q 2>/dev/null
redis-cli ping 2>/dev/null | grep -q PONG || { pm2 start redis-server --name redis -- --daemonize no; sleep 3; }
redis-cli hset cybra:executor:mapping write_module parliament_write_module_handler.sh >/dev/null
up(){ n="$1" s="$2" i="$3"; shift 3; pm2 describe "$n" >/dev/null 2>&1 && pm2 restart "$n" >/dev/null 2>&1 || [ -f "$s" ] && pm2 start "$s" --name "$n" --interpreter "$i" "$@" >/dev/null 2>&1; }
up parliament        "$BASE/parliament_executor_v6.py"           python3
up menu-worker       "$BASE/parliament_menu_worker.sh"           bash
up menu-autorobot    "$BASE/bin/cybra_menu_autorobot.py"         python3 -- loop 120
up cybra-evo-ctrl    "$BASE/bin/cybra_evo_controller.py"         python3 -- loop 600
up cybra-autopilot   "$BASE/bin/cybra_autopilot.py"              python3 -- loop 900
up hidl-worker       "$BASE/bin/cybra_hidl_worker.py"            python3
up hidl-notifier     "$BASE/bin/cybra_hidl_notifier.py"          python3
up taxi-events       "$BASE/bin/cybra_taxi_events.py"            python3
up cybra-api         "$BASE/api/run.sh"                          bash
pm2 save >/dev/null 2>&1
[ -f bin/cybra_bar_menu_160_contracts.sh ] && bash bin/cybra_bar_menu_160_contracts.sh 2>&1 | tail -10
[ -f bin/cybra_state_100.sh ] && bash bin/cybra_state_100.sh 2>&1 | tail -10
git add -A; git commit -m "bootstrap: $(hostname) ready" 2>&1 | head -1; git push origin main 2>&1 | tail -2
echo "═══ DONE ═══"
