#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HANDLER="$1"; shift || true
CYBRA="$HOME/CYBRA"; cd "$CYBRA"
NAME=$(basename "$HANDLER" .sh)
LAYERS=$(python3 -c "
import json
try: d=json.load(open('state/layers/permissions.json'))
except: d={'executors':{}}
p=d['executors'].get('$NAME',{})
print(','.join(p.get('layers',['L0_sandbox'])))
" 2>/dev/null)
[ -z "$LAYERS" ] && LAYERS="L0_sandbox"
if [ ! -f "$HANDLER" ]; then
  [ -f "./$HANDLER" ] && HANDLER="./$HANDLER" || { echo '{"ok":false,"error":"handler_not_found"}'; exit 1; }
fi
exec bash "$HANDLER" "$@"
