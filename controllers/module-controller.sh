#!/data/data/com.termux/files/usr/bin/bash
# Контролер модулів: нода → 65MB → binmix → модуль
CYBRA="$HOME/CYBRA"
NODE_CTRL="$CYBRA/controllers/node-controller.sh"
SANDBOX="$CYBRA/sandbox"
BINMIX="$CYBRA/bin/cybra_binmix"
LIMIT=$((65 * 1024 * 1024))
LOG="$CYBRA/logs/module-controller.log"
mkdir -p "$CYBRA/logs" "$SANDBOX"/{bin,tmp,keep,trash}
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

# 1. Нода (100% стан)
[ -x "$NODE_CTRL" ] && "$NODE_CTRL" path >/dev/null 2>&1 || { echo "⛔ нода не 100%"; exit 1; }

# 2. 65MB
SIZE=$(du -sb "$SANDBOX" 2>/dev/null | awk '{print $1}' || echo 0)
if [ "$SIZE" -ge "$LIMIT" ]; then
    log "CLEAN sandbox"
    rm -rf "$SANDBOX"/trash/* "$SANDBOX"/tmp/* 2>/dev/null
    [ -x "$SANDBOX/sandbox_cleanup.sh" ] && "$SANDBOX/sandbox_cleanup.sh" >/dev/null 2>&1
fi

# 3. Binmix
[ -x "$BINMIX" ] && "$BINMIX" status >/dev/null 2>&1

# 4. Виклик модуля
MOD="$1"; shift
[ -z "$MOD" ] && { echo "usage: module-controller <module.sh> [args]"; exit 1; }
[ -f "$MOD" ] || { echo "❌ не знайдено: $MOD"; exit 1; }
log "RUN: $MOD"
exec bash "$MOD" "$@"
