#!/data/data/com.termux/files/usr/bin/bash
set -u
ROOT="$HOME/CYBRA"; CONTROL="$ROOT/control"
LOG="$ROOT/logs/cybra_master.log"
PIDFILE="$CONTROL/cybra_master.pid"
STATE="$CONTROL/cybra_master.state"
INTERVAL=20
mkdir -p "$CONTROL" "$ROOT/logs"
log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock >/dev/null 2>&1 || true

if [ -f "$PIDFILE" ]; then
    OLD=$(cat "$PIDFILE" 2>/dev/null || true)
    if [ -n "$OLD" ] && [ "$OLD" != "$$" ] && kill -0 "$OLD" 2>/dev/null; then
        echo "master already pid=$OLD"; exit 0
    fi
    rm -f "$PIDFILE"
fi
echo "$$" > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT INT TERM
log "master started pid=$$"

spawn_if_dead(){
    local SCRIPT="$1" PIDF="$2" NAME="$3"
    [ -x "$SCRIPT" ] || return 0
    if [ -f "$PIDF" ]; then
        local P=$(cat "$PIDF" 2>/dev/null || true)
        if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then return 0; fi
    fi
    log "$NAME down → restart"
    nohup "$SCRIPT" >> "$LOG" 2>&1 &
    sleep 1
    return 1
}

while true; do
    # network watchdog
    spawn_if_dead "$ROOT/11_cybra_network_master_watchdog.sh" \
                  "$CONTROL/network_master_watchdog.pid" "network-wd" && WD=true || WD=false

    # autobackup
    spawn_if_dead "$ROOT/cybra_autobackup.sh" \
                  "$CONTROL/cybra_autobackup.pid" "autobackup" && AB=true || AB=false

    # node watchdog
    spawn_if_dead "$ROOT/03_cybra_node_watchdog.sh" \
                  "$CONTROL/cybra_node_watchdog.pid" "node-wd" && NWD=true || NWD=false

    NODE=false
    [ -f "$ROOT/node_cybra/bin/cybra_node_start.sh" ] && NODE=true

    cat > "$STATE" <<STATE
MASTER=ONLINE
AUTO_START=true
AUTO_HEAL=true
WAKE_LOCK=true
NODE=$NODE
NETWORK_WATCHDOG=$WD
AUTOBACKUP=$AB
NODE_WATCHDOG=$NWD
TRUE_100=false
LIVE=false
PHYSICAL_EXECUTION=false
LAST_CHECK=$(date +%s)
STATE_REASON=CYBRA_MASTER
STATE

    sleep "$INTERVAL"
done
