#!/data/data/com.termux/files/usr/bin/bash
# state controller for api_DELETE_api_wallet_{addr}
set -u
SNAP="$HOME/CYBRA/state/snapshots/api_DELETE_api_wallet_{addr}.json"
[ -f "$SNAP" ] || { echo "❌ no snapshot"; exit 1; }
STATUS=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('ok'))" 2>/dev/null)
DETAIL=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('detail',''))" 2>/dev/null)
if [ "$STATUS" = "True" ]; then echo "✅ api_DELETE_api_wallet_{addr} ($DETAIL)"; exit 0
else echo "❌ api_DELETE_api_wallet_{addr} ($DETAIL)"; exit 1; fi
