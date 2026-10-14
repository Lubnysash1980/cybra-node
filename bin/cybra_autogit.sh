#!/data/data/com.termux/files/usr/bin/bash
# Автокоміт CYBRA кожні 15 хв (викликається через pm2 або cron)

cd "$HOME/CYBRA" || exit 1

if [ -z "$(git status --porcelain)" ]; then
    exit 0
fi

TS=$(date -u +"%Y-%m-%d %H:%M UTC")
git add -A
git commit -m "auto: snapshot $TS" --quiet
git push origin main --quiet 2>&1 | tee -a ~/CYBRA/logs/autogit.log

echo "[$(date)] pushed at $TS" >> ~/CYBRA/logs/autogit.log
