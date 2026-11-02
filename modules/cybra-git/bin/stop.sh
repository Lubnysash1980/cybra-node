#!/data/data/com.termux/files/usr/bin/bash
set -u
pm2 delete cybra-autogit 2>/dev/null
pm2 save --force >/dev/null 2>&1
echo "stopped"
