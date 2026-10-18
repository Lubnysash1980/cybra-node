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
done
