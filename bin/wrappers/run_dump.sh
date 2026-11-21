#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
while true; do bin/cybra_dump.sh; sleep 900; done
