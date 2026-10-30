#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
LOG="$HOME/CYBRA/logs/autobuild_loop.log"; mkdir -p "$(dirname "$LOG")"
lg(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
for i in 1 2 3; do
  lg "═══ CYCLE $i/3 ═══"
  python3 "$HOME/CYBRA/bin/cybra_autobuild_parliament.py" 2>&1 | tee -a "$LOG"
  rc=$?
  S=$(jq -r .score_pct "$HOME/.pm2/evolution/score.json" 2>/dev/null || echo 0)
  lg "  cycle $i: rc=$rc score=$S"
  if [ "$rc" = "0" ]; then lg "✅ 100%"; break; fi
  sleep 10
done
lg "═══ LOOP DONE ═══"
