#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
pm2 describe cybra-autogit >/dev/null 2>&1 || \
  pm2 start "$MOD/bin/autogit.sh" --name cybra-autogit --interpreter bash --max-memory-restart 65M -- --daemon 300
pm2 save --force >/dev/null 2>&1
echo "started"
