#!/data/data/com.termux/files/usr/bin/bash
# module_258: eco_global (eco) — taxi_premium
# generated 2026-10-25T23:07:35Z
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-status}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="eco_global"
MODULE_CAT="eco"

case "$ACTION" in
  sync)
    cd "$CYBRA"
    git add state/taxi_premium_spec.json state/taxi_premium_config.json \
            modules/module_2[4-5][0-9]_* controllers/premium_module_*.ctrl.sh \
            taxi_premium bin/cybra_taxi_premium_deploy.py 2>/dev/null
    git commit -m "eco: sync taxi_premium to all nodes" 2>&1 | head -2
    git push origin main 2>&1 | tail -2
    echo "✅ pushed — other devices pull next cycle"
    ;;
  status|*)
    echo "════ ${MODULE_LABEL} ════"
    echo "  device:  $(hostname)"
    echo "  nodes:   $(ls "$CYBRA/nodes/heartbeats/" 2>/dev/null | wc -l)"
    echo "  HEAD:    $(git -C "$CYBRA" log -1 --format='%h %s' 2>/dev/null)"
    echo "  hint:    $0 sync  — push to all nodes via git"
    ;;
esac
