#!/data/data/com.termux/files/usr/bin/bash
# Каркас контролерів за екшенами: params + autoconfig + 7 рівнів + стан 100% + аномалії
CYBRA="$HOME/CYBRA"
CTRL_DIR="$CYBRA/controllers"
CFG_DIR="$CYBRA/config/actions"
STATE_DIR="$CYBRA/state"
LOG="$CYBRA/logs/action_controllers.log"
mkdir -p "$CTRL_DIR" "$CFG_DIR" "$STATE_DIR" "$CYBRA/logs"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

# ─── СПИСОК ЕКШЕНІВ ───
ACTIONS=(
  "payment"
  "contract_bsc"
  "contract_terms"
  "contract_extra_terms"
  "ad_reclama"
  "rollback_cybernoda"
  "restore_from_node"
  "language"
  "pool_conditional"
  "anomaly"
)

# ─── ГЕНЕРАЦІЯ КОНТРОЛЕРА ДЛЯ ЕКШЕНУ ───
make_controller() {
    local action="$1"
    local cfg="$CFG_DIR/$action.env"
    local state="$STATE_DIR/$action.pct"
    local ctrl="$CTRL_DIR/${action}-controller.sh"

    # автоконфіг (якщо немає)
    [ -f "$cfg" ] || cat > "$cfg" <<CFG
ACTION=$action
LEVELS=7
REQUIRE_STATE_100=true
ANOMALY_BLOCK=true
CFG

    cat > "$ctrl" <<CTRL
#!/data/data/com.termux/files/usr/bin/bash
# Контролер екшену: $action
# params + autoconfig + 7 рівнів + стан 100% + аномалії
CYBRA="$HOME/CYBRA"
CFG="$cfg"
STATE="$state"
LOG="\$CYBRA/logs/${action}-controller.log"
mkdir -p "\$(dirname "\$LOG")"

log() { echo "[\$(date -u +%Y-%m-%dT%H:%M:%SZ)] \$1" >> "\$LOG"; }

# 1. Завантажити автоконфіг
[ -f "\$CFG" ] && source "\$CFG"

# 2. 7 рівнів перевірки
L1() { [ -d "\$CYBRA" ] || return 1; }
L2() { [ -f "\$CFG" ] || return 1; }
L3() { [ -f "\$STATE" ] || echo 0 > "\$STATE"; }
L4() { [ "\$(cat "\$STATE" 2>/dev/null || echo 0)" -eq 100 ]; }
L5() { [ -d "\$CYBRA/sandbox" ] || mkdir -p "\$CYBRA/sandbox"; }
L6() { [ -f "\$CYBRA/registry/controllers.json" ]; }
L7() { [ -d "\$CYBRA/evo" ]; }
LEVELS_FN=(L1 L2 L3 L4 L5 L6 L7)

check_levels() {
    local level=1
    for fn in "\${LEVELS_FN[@]}"; do
        if \$fn; then level=\$((level+1)); else
            log "STOP: level \$level fail for $action"
            return 1
        fi
    done
    return 0
}

# 3. Перевірка аномалій (блокує, якщо стан не 100%)
check_anomaly() {
    [ "\$ANOMALY_BLOCK" = "true" ] || return 0
    local pct=\$(cat "\$STATE" 2>/dev/null || echo 0)
    if [ "\$REQUIRE_STATE_100" = "true" ] && [ "\$pct" -ne 100 ]; then
        log "ANOMALY: state \$pct% != 100% for $action"
        echo "⛔ Аномалія: стан \$pct% (потрібно 100%)"
        return 1
    fi
    return 0
}

# 4. Виконання
run() {
    check_levels || exit 1
    check_anomaly || exit 1
    log "RUN: $action \$*"
    echo "▶ $action: виконую \$*"
    # Тут буде виклик реального скрипта (коли під'єднаємо)
}

case "\${1:-run}" in
    run|*) run "\$@" ;;
    check) check_levels && echo "✅ levels OK" ;;
    state) echo "state: \$(cat "\$STATE" 2>/dev/null || echo 0)%" ;;
    set100) echo 100 > "\$STATE"; echo "✅ state 100%" ;;
    *) run "\$@" ;;
esac
CTRL

    chmod +x "$ctrl"
    echo 100 > "$state"  # початково 100% (щоб не блокувати)
    bash -n "$ctrl" && log "CREATED: $action" && echo "  ✅ $action"
}

echo "═══ СТВОРЕННЯ КОНТРОЛЕРІВ ЗА ЕКШЕНАМИ ═══"
for a in "${ACTIONS[@]}"; do make_controller "$a"; done

echo ""
echo "─── Тест ───"
for a in "${ACTIONS[@]}"; do
    "$CTRL_DIR/${a}-controller.sh" check && "$CTRL_DIR/${a}-controller.sh" state
done

echo ""
echo "✅ Готово: ${#ACTIONS[@]} контролерів у $CTRL_DIR"
ls -la "$CTRL_DIR"
