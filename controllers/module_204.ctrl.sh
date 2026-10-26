#!/data/data/com.termux/files/usr/bin/bash
# state controller for module_204
set -u
SNAP="$HOME/CYBRA/state/snapshots/module_204.json"
[ -f "$SNAP" ] || { echo "❌ no snapshot"; exit 1; }
STATUS=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('ok'))" 2>/dev/null)
DETAIL=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('detail',''))" 2>/dev/null)
if [ "$STATUS" = "True" ]; then echo "✅ module_204 ($DETAIL)"; exit 0
else echo "❌ module_204 ($DETAIL)"; exit 1; fi
