#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
exec bin/cybra_autogit.sh --daemon 300
