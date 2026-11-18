#!/data/data/com.termux/files/usr/bin/bash
cd ~/CYBRA
PIDFILE="barmenu/state/autosave.pid"
mkdir -p barmenu/snapshots barmenu/state
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    exit 0
fi
echo $$ > "$PIDFILE"
trap 'rm -f "$PIDFILE"' EXIT
while true; do
    TS=$(date +%Y%m%d_%H%M%S)
    tar -czf "barmenu/snapshots/auto_$TS.tar.gz" \
        --exclude='node_modules' --exclude='.git' --exclude='barmenu/snapshots' \
        modules bin parliament barmenu .env 2>/dev/null
    find barmenu/snapshots -name 'auto_*.tar.gz' -mmin +1440 -delete 2>/dev/null
    sleep 300
done
