#!/data/data/com.termux/files/usr/bin/bash
# state controller for dart_wallet_screen
set -u
SNAP="$HOME/CYBRA/state/snapshots/dart_wallet_screen.json"
[ -f "$SNAP" ] || { echo "❌ no snapshot"; exit 1; }
STATUS=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('ok'))" 2>/dev/null)
DETAIL=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('detail',''))" 2>/dev/null)
if [ "$STATUS" = "True" ]; then echo "✅ dart_wallet_screen ($DETAIL)"; exit 0
else echo "❌ dart_wallet_screen ($DETAIL)"; exit 1; fi
