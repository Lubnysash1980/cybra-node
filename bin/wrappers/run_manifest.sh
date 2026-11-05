#!/data/data/com.termux/files/usr/bin/bash
cd "$(dirname "$0")/../.." || exit 1
while true; do python3 bin/cybra_manifest.py; sleep 30; done
