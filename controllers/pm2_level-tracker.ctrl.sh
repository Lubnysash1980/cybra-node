#!/data/data/com.termux/files/usr/bin/bash
# state controller for pm2_level-tracker
set -u
SNAP="$HOME/CYBRA/state/snapshots/pm2_level-tracker.json"
[ -f "$SNAP" ] || { echo "❌ no snapshot"; exit 1; }
STATUS=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('ok'))" 2>/dev/null)
DETAIL=$(python3 -c "import json;d=json.load(open('$SNAP'));print(d.get('detail',''))" 2>/dev/null)
if [ "$STATUS" = "True" ]; then echo "✅ pm2_level-tracker ($DETAIL)"; exit 0
else echo "❌ pm2_level-tracker ($DETAIL)"; exit 1; fi
