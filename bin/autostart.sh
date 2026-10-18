#!/data/data/com.termux/files/usr/bin/bash
# CYBRA autostart — піднімає PM2-процеси, якщо їх немає

export HOME="/data/data/com.termux/files/home"
export PREFIX="/data/data/com.termux/files/usr"
export PATH="$PREFIX/bin:$HOME/bin:$HOME/CYBRA/bin:$PATH"

# Чекаємо, поки Termux ініціалізується
sleep 2

cd "$HOME/CYBRA" || exit 1

# Якщо pm2 є — resurrect
if command -v pm2 >/dev/null 2>&1; then
    pm2 resurrect >/dev/null 2>&1
fi

# Лог
echo "autostart at $(date)" >> "$HOME/CYBRA/logs/autostart.log"
pm2 ls >> "$HOME/CYBRA/logs/autostart.log" 2>&1
