#!/data/data/com.termux/files/usr/bin/bash
# CYBRA Controller v2 — 7 рівнів
set -u

CYBRA_DIR="$HOME/CYBRA"
STATE_FILE="$CYBRA_DIR/.ctl.state"
LOG_FILE="$CYBRA_DIR/.ctl.log"
SAMPLE_DIR="$CYBRA_DIR/.samples"
LOCK_FILE="$CYBRA_DIR/.ctl.lock"

FAST_INTERVAL=2
SLOW_WINDOW=5
SNAP_THRESHOLD=40
RECOVERY_STEP=10

# Групи процесів (підлаштовано під цей пристрій)
CORE_PROCS="cybra-api cybra-monolith redis"
HIGH_PROCS="taxi-events level-tracker menu-worker parliament"
MED_PROCS="cybra-openid cybra-openid-health cybra-pool cybra-brain cybra-metrics"
LOW_PROCS="cybra-autogit mock-ai"
ALL_PROCS="$CORE_PROCS $HIGH_PROCS $MED_PROCS $LOW_PROCS"

mkdir -p "$SAMPLE_DIR"
[ -f "$STATE_FILE" ] || echo 4 > "$STATE_FILE"

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

sampler_ram() {
    while true; do
        free | awk '/Mem:/ {printf "%.0f\n", ($3/$2)*100}' > "$SAMPLE_DIR/ram.$$"
        mv "$SAMPLE_DIR/ram.$$" "$SAMPLE_DIR/ram"; sleep "$FAST_INTERVAL"
    done
}
sampler_cpu() {
    while true; do
        local load=$(awk '{print $1}' /proc/loadavg); local cores=$(nproc)
        awk -v l="$load" -v c="$cores" 'BEGIN {printf "%.2f\n", l/c}' > "$SAMPLE_DIR/cpu.$$"
        mv "$SAMPLE_DIR/cpu.$$" "$SAMPLE_DIR/cpu"; sleep "$FAST_INTERVAL"
    done
}
sampler_io() {
    while true; do
        local iow=$(awk '/^cpu / {print $6}' /proc/stat); sleep 1
        local iow2=$(awk '/^cpu / {print $6}' /proc/stat)
        local t1=$(awk '/^cpu / {s=0; for(i=2;i<=11;i++) s+=$i; print s}' /proc/stat); sleep 1
        local t2=$(awk '/^cpu / {s=0; for(i=2;i<=11;i++) s+=$i; print s}' /proc/stat)
        local dio=$(( iow2 - iow )); local dt=$(( t2 - t1 ))
        [ "$dt" -gt 0 ] && echo "$(( dio * 100 / dt ))" > "$SAMPLE_DIR/io.$$" || echo 0 > "$SAMPLE_DIR/io.$$"
        mv "$SAMPLE_DIR/io.$$" "$SAMPLE_DIR/io"; sleep "$FAST_INTERVAL"
    done
}

push_history() {
    echo "$2" >> "$SAMPLE_DIR/$1.hist"
    tail -n "$SLOW_WINDOW" "$SAMPLE_DIR/$1.hist" > "$SAMPLE_DIR/$1.tmp" && mv "$SAMPLE_DIR/$1.tmp" "$SAMPLE_DIR/$1.hist"
}
avg_history() { awk '{s+=$1; n++} END {if (n>0) printf "%.0f", s/n; else print 0}' "$SAMPLE_DIR/$1.hist"; }

calc_level_from() {
    local ram=$1 cpu=$2 io=$3
    local score=$(( ram + io * 2 + $(awk -v c="$cpu" 'BEGIN{printf "%d", c*30}') ))
    if   [ "$score" -ge 120 ]; then echo 1
    elif [ "$score" -ge 100 ]; then echo 2
    elif [ "$score" -ge 80 ];  then echo 3
    elif [ "$score" -ge 60 ];  then echo 4
    elif [ "$score" -ge 40 ];  then echo 5
    elif [ "$score" -ge 20 ];  then echo 6
    else echo 7; fi
}

apply_at_full() {
    local level=$1 mem core_mem
    case "$level" in
        1) mem=200M; core_mem=250M ;; 2) mem=300M; core_mem=350M ;;
        3) mem=350M; core_mem=400M ;; 4) mem=400M; core_mem=450M ;;
        5) mem=500M; core_mem=550M ;; 6) mem=550M; core_mem=600M ;;
        7) mem=600M; core_mem=700M ;;
    esac
    for p in $CORE_PROCS; do pm2 restart "$p" --max-memory-restart "$core_mem" 2>/dev/null || true; done
    for p in $HIGH_PROCS $MED_PROCS $LOW_PROCS; do pm2 restart "$p" --max-memory-restart "$mem" 2>/dev/null || true; done
}

stop_group() { for p in $1; do pm2 stop "$p" 2>/dev/null & done; wait; }
start_group_gradual() { for p in $1; do pm2 start "$p" 2>/dev/null || true; sleep "$RECOVERY_STEP"; done; }

apply_level() {
    local level=$1
    case "$level" in
        1) log "🛑 L1 SLEEP"; stop_group "$HIGH_PROCS $MED_PROCS $LOW_PROCS" ;;
        2) log "🔴 L2 CRIT"; stop_group "$MED_PROCS $LOW_PROCS"; start_group_gradual "$HIGH_PROCS" ;;
        3) log "🟠 L3 LOW"; stop_group "$LOW_PROCS"; start_group_gradual "$HIGH_PROCS $MED_PROCS" ;;
        4) log "🟡 L4 NORMAL"; stop_group "$LOW_PROCS"; start_group_gradual "$CORE_PROCS $HIGH_PROCS $MED_PROCS" ;;
        5) log "🟢 L5 HIGH"; start_group_gradual "$ALL_PROCS" ;;
        6) log "🔵 L6 TURBO"; start_group_gradual "$ALL_PROCS" ;;
        7) log "🟣 L7 MAX"; start_group_gradual "$ALL_PROCS" ;;
    esac
    apply_at_full "$level"
    echo "$level" > "$STATE_FILE"
}

# Force-level режим (для меню)
if [ "${1:-}" = "--force-level" ] && [ -n "${2:-}" ]; then
    log "🎯 Force-level $2"
    apply_level "$2"
    exit 0
fi

# Daemon
if [ -f "$LOCK_FILE" ] && kill -0 "$(cat "$LOCK_FILE")" 2>/dev/null; then
    log "❌ CTL v2 вже працює (PID $(cat "$LOCK_FILE"))"; exit 0
fi
echo $$ > "$LOCK_FILE"
trap 'kill $(jobs -p) 2>/dev/null; rm -f "$LOCK_FILE"; log "⏹️ CTL v2 stop"' EXIT INT TERM

log "▶️ CTL v2 старт"
sampler_ram & sampler_cpu & sampler_io &

while true; do
    RAM=$(cat "$SAMPLE_DIR/ram" 2>/dev/null || echo 0)
    CPU=$(cat "$SAMPLE_DIR/cpu" 2>/dev/null || echo 0)
    IO=$(cat "$SAMPLE_DIR/io" 2>/dev/null || echo 0)
    push_history ram "$RAM"; push_history cpu "$CPU"; push_history io "$IO"
    AVG_RAM=$(avg_history ram); AVG_CPU=$(avg_history cpu); AVG_IO=$(avg_history io)
    LEVEL_NOW=$(calc_level_from "$RAM" "$CPU" "$IO")
    LEVEL_AVG=$(calc_level_from "$AVG_RAM" "$AVG_CPU" "$AVG_IO")
    LEVEL_CUR=$(cat "$STATE_FILE")
    DELTA_RAM=$(( RAM - AVG_RAM )); [ "$DELTA_RAM" -lt 0 ] && DELTA_RAM=$(( -DELTA_RAM ))
    SNAP=0
    [ "$AVG_RAM" -gt 0 ] && [ $(( DELTA_RAM * 100 / AVG_RAM )) -ge "$SNAP_THRESHOLD" ] && SNAP=1
    if [ "$SNAP" -eq 1 ] && [ "$LEVEL_NOW" != "$LEVEL_CUR" ]; then
        log "⚡ SNAP: RAM ${AVG_RAM}→${RAM}%, L$LEVEL_CUR→L$LEVEL_NOW"
        apply_level "$LEVEL_NOW"
    elif [ "$LEVEL_AVG" != "$LEVEL_CUR" ]; then
        log "🔀 SMOOTH: L$LEVEL_CUR→L$LEVEL_AVG (ram=$AVG_RAM cpu=$AVG_CPU io=$AVG_IO)"
        apply_level "$LEVEL_AVG"
    fi
    sleep "$FAST_INTERVAL"
done
