#!/data/data/com.termux/files/usr/bin/bash
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
if [ -n "${1:-}" ]; then
  "$CYBRA/bin/cybra_restore_component.sh" "$1"
else
  "$CYBRA/bin/cybra_restore_component.sh" all
fi
