#!/data/data/com.termux/files/usr/bin/bash
# state controller for api_GET_api_wallet
set -u
SNAP="$HOME/CYBRA/state/snapshots/api_GET_api_wallet.json"
[ -f "$SNAP" ] || { echo "❌ no snapshot"; exit 1; }
STATUS=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('ok'))" 2>/dev/null)
DETAIL=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('detail',''))" 2>/dev/null)
if [ "$STATUS" = "True" ]; then echo "✅ api_GET_api_wallet ($DETAIL)"; exit 0
else echo "❌ api_GET_api_wallet ($DETAIL)"; exit 1; fi
