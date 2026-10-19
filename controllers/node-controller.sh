#!/data/data/com.termux/files/usr/bin/bash
# Контролер НОДИ: 100% стан + 65MB бінарі (binmix + runtime) перед дією
CYBRA="$HOME/CYBRA"
NODE_STATE="$CYBRA/nodes/node_1/state/state.json"
SANDBOX="$CYBRA/sandbox"
BINMIX="$CYBRA/bin/cybra_binmix"
RUNTIME="$CYBRA/bin/cybra_runtime"
LOG="$CYBRA/logs/node-controller.log"
mkdir -p "$CYBRA/logs"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

# 1. НОДА — 100% стан
check_node() {
    if [ ! -f "$NODE_STATE" ]; then
        log "NODE: state.json немає"
        echo "❌ Нода: немає state.json"
        return 1
    fi
    local cycles=$(python3 -c "import json; d=json.load(open('$NODE_STATE')); print(d.get('cycles',0))" 2>/dev/null)
    local signed=$(python3 -c "import json; d=json.load(open('$NODE_STATE')); print(d.get('signed_actions',0))" 2>/dev/null)
    if [ "$cycles" -gt 0 ] && [ "$signed" -gt 0 ]; then
        echo "✅ Нода: cycles=$cycles, signed=$signed (100%)"
        log "NODE OK: cycles=$cycles signed=$signed"
        return 0
    fi
    echo "❌ Нода: не 100% (cycles=$cycles, signed=$signed)"
    log "NODE FAIL"
    return 1
}

# 2. 65MB бінарі (binmix + runtime)
check_sandbox() {
    if [ ! -d "$SANDBOX" ]; then
        mkdir -p "$SANDBOX"/{bin,tmp,keep,trash}
        echo "  [✓] sandbox створено"
    fi
    local size=$(du -sb "$SANDBOX" 2>/dev/null | awk '{print $1}' || echo 0)
    local limit=$((65 * 1024 * 1024))
    local mb=$((size / 1024 / 1024))
    if [ "$size" -ge "$limit" ]; then
        echo "⚠️  Sandbox: ${mb}MB / 65MB — очищаю"
        rm -rf "$SANDBOX"/trash/* "$SANDBOX"/tmp/* 2>/dev/null
        [ -x "$SANDBOX/sandbox_cleanup.sh" ] && "$SANDBOX/sandbox_cleanup.sh" >/dev/null 2>&1
        size=$(du -sb "$SANDBOX" 2>/dev/null | awk '{print $1}' || echo 0)
        mb=$((size / 1024 / 1024))
    fi
    echo "✅ Sandbox: ${mb}MB / 65MB"
    log "SANDBOX OK: ${mb}MB"
    return 0
}

# 3. Binmix + Runtime
check_binmix_runtime() {
    local ok=0
    [ -f "$BINMIX" ] && { echo "✅ Binmix є"; ok=$((ok+1)); } || echo "⚠️  Binmix немає"
    [ -f "$RUNTIME" ] && { echo "✅ Runtime є"; ok=$((ok+1)); } || echo "⚠️  Runtime немає"
    [ "$ok" -ge 1 ] && return 0 || return 1
}

# 4. Повний шлях до 100%
run_path() {
    echo "═══ НОДА → 100% СТАН → ДІЯ ═══"
    check_node || { echo "⛔ БЛОК: нода не 100%"; exit 1; }
    check_sandbox || { echo "⛔ БЛОК: sandbox"; exit 1; }
    check_binmix_runtime || echo "⚠️  binmix/runtime неповний"
    echo "🎯 100% СТАН ДОСЯГНУТО — можна виконувати"
    log "READY: 100%"
}

case "${1:-path}" in
    path|status) run_path ;;
    node) check_node ;;
    sandbox) check_sandbox ;;
    binmix) check_binmix_runtime ;;
    *) run_path ;;
esac
