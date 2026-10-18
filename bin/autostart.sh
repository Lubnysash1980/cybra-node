#!/data/data/com.termux/files/usr/bin/bash
# CYBRA autostart — піднімає PM2-процеси, якщо їх немає
if ! command -v pm2 >/dev/null 2>&1; then
    exit 0
fi
# Якщо PM2-демон не запущений або немає процесів — resurrect
if ! pm2 ls 2>/dev/null | grep -qE "online|stopped|errored"; then
    pm2 resurrect >/dev/null 2>&1
fi
