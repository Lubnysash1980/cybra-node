#!/data/data/com.termux/files/usr/bin/bash

mkdir -p "$HOME/CYBRA/state/redis"

exec redis-server \
    --bind 127.0.0.1 \
    --port 6379 \
    --protected-mode yes \
    --daemonize no \
    --appendonly yes \
    --dir "$HOME/CYBRA/state/redis"
