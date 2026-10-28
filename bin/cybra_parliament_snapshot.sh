#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
NAME="${1:-auto_$(date +%Y%m%d_%H%M%S)}"
DIR="state/snapshots/parliament_$NAME"
mkdir -p "$DIR"
cp state/snapshots/_master.json "$DIR/" 2>/dev/null
cp state/identity/registry.json "$DIR/" 2>/dev/null
cp state/layers/*.json "$DIR/" 2>/dev/null
TAR="state/snapshots/parliament_${NAME}.tar.gz"
tar -czf "$TAR" -C state/snapshots "parliament_$NAME" 2>/dev/null
echo "✅ $TAR ($(du -h "$TAR" | awk '{print $1}'))"
echo "   pct: $(python3 -c "import json;print(json.load(open('state/snapshots/_master.json'))['pct'])" 2>/dev/null || echo '?')%"
