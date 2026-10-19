#!/data/data/com.termux/files/usr/bin/bash
# CYBRA watchdog — нескінченний цикл: if kill -> start_pm2
# Перевіряє кожні 30 секунд, чи PM2-процеси живі. Якщо ні — resurrect.

export HOME="/data/data/com.termux/files/home"
export PREFIX="/data/data/com.termux/files/usr"
export PATH="$PREFIX/bin:$HOME/bin:$HOME/CYBRA/bin:$PATH"

LOG="$HOME/CYBRA/logs/watchdog.log"
mkdir -p "$HOME/CYBRA/logs"

INTERVAL=30   # секунд між перевірками
EXPECTED=9    # скільки процесів має бути online

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

log "=== Watchdog Start (interval=${INTERVAL}s, expected=${EXPECTED}) ==="

while true; do
    # Скільки процесів online?
    ONLINE=$(pm2 ls 2>/dev/null | grep -c "online" || echo 0)

    if [ "$ONLINE" -lt "$EXPECTED" ]; then
        log "ALERT: online=$ONLINE < expected=$EXPECTED — resurrect"
        cd "$HOME/CYBRA" || continue
        pm2 resurrect >/dev/null 2>&1
        sleep 3
        NEW_ONLINE=$(pm2 ls 2>/dev/null | grep -c "online" || echo 0)
        log "RESURRECT: now online=$NEW_ONLINE"
    fi

    sleep "$INTERVAL"

# ─── 7 РІВНІВ СКЛАДНОСТІ ───
LEVEL_FILE="/data/data/com.termux/files/home/CYBRA/state/cybra-watchdog.sh.level"
level_now() { [ -f "$LEVEL_FILE" ] && cat "$LEVEL_FILE" || echo 1; }
level_set() { echo "$1" > "$LEVEL_FILE"; }
level1() { [ -d "$HOME/CYBRA" ] && return 0 || return 1; }
level2() { command -v bash >/dev/null && return 0 || return 1; }
level3() { [ -d "$HOME/CYBRA/modules" ] && return 0 || return 1; }
level4() { [ -d "$HOME/CYBRA/logs" ] && return 0 || return 1; }
level5() { [ -f "$HOME/CYBRA/evo/evo_core.py" ] && return 0 || return 1; }
level6() { [ -d "$HOME/CYBRA/modules" ] && return 0 || return 1; }
level7() { [ -d "$HOME/CYBRA/sandbox" ] && return 0 || return 1; }
run_levels() {
    local cur=$(level_now)
    for i in 1 2 3 4 5 6 7; do
        [ "$i" -lt "$cur" ] && continue
        if "level$i"; then level_set "$i"; else return 0; fi
    done
}
run_levels

done
