#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
"$CYBRA/bin/cybra_dump_components.sh"
"$CYBRA/bin/cybra_dump.sh"
"$MOD/bin/status.sh" >/dev/null
echo "dump done"
