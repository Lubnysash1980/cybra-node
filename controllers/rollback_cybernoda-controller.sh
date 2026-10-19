#!/data/data/com.termux/files/usr/bin/bash
# Контролер екшену: rollback_cybernoda
# params + autoconfig + 7 рівнів + стан 100% + аномалії
CYBRA="/data/data/com.termux/files/home/CYBRA"
CFG="/data/data/com.termux/files/home/CYBRA/config/actions/rollback_cybernoda.env"
STATE="/data/data/com.termux/files/home/CYBRA/state/rollback_cybernoda.pct"
LOG="$CYBRA/logs/rollback_cybernoda-controller.log"
mkdir -p "$(dirname "$LOG")"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG"; }

# 1. Завантажити автоконфіг
[ -f "$CFG" ] && source "$CFG"

# 2. 7 рівнів перевірки
L1() { [ -d "$CYBRA" ] || return 1; }
L2() { [ -f "$CFG" ] || return 1; }
L3() { [ -f "$STATE" ] || echo 0 > "$STATE"; }
L4() { [ "$(cat "$STATE" 2>/dev/null || echo 0)" -eq 100 ]; }
L5() { [ -d "$CYBRA/sandbox" ] || mkdir -p "$CYBRA/sandbox"; }
L6() { [ -f "$CYBRA/registry/controllers.json" ]; }
L7() { [ -d "$CYBRA/evo" ]; }
LEVELS_FN=(L1 L2 L3 L4 L5 L6 L7)

check_levels() {
    local level=1
    for fn in "${LEVELS_FN[@]}"; do
        if $fn; then level=$((level+1)); else
            log "STOP: level $level fail for rollback_cybernoda"
            return 1
        fi
    done
    return 0
}

# 3. Перевірка аномалій (блокує, якщо стан не 100%)
check_anomaly() {
    [ "$ANOMALY_BLOCK" = "true" ] || return 0
    local pct=$(cat "$STATE" 2>/dev/null || echo 0)
    if [ "$REQUIRE_STATE_100" = "true" ] && [ "$pct" -ne 100 ]; then
        log "ANOMALY: state $pct% != 100% for rollback_cybernoda"
        echo "⛔ Аномалія: стан $pct% (потрібно 100%)"
        return 1
    fi
    return 0
}

# 4. Виконання
run() {
    check_levels || exit 1
    check_anomaly || exit 1
    log "RUN: rollback_cybernoda $*"
    echo "▶ rollback_cybernoda: виконую $*"
    # Тут буде виклик реального скрипта (коли під'єднаємо)
}

case "${1:-run}" in
    check) check_levels && echo "✅ levels OK" ;;
    state) echo "state: $(cat "$STATE" 2>/dev/null || echo 0)%" ;;
    set100) echo 100 > "$STATE"; echo "✅ state 100%" ;;
    run|*) run "$@" ;;
esac
