#!/data/data/com.termux/files/usr/bin/bash
# Щотижневий cleanup: деградація → rollback, еволюція → lock. + cleanup старих бекапів.
set -uo pipefail
CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/weekly_cleanup.log"
mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }

log "════ WEEKLY CLEANUP START ════"

# 1. evo_guard cycle — це і є "підчистка": -3% → rollback, +3% → lock
log "── 1. evo_guard cycle ──"
python3 "$CYBRA/bin/cybra_evo_guard.py" cycle 2>&1 | tee -a "$LOG"

# 2. Поточний статус після
log "── 2. status ──"
python3 "$CYBRA/bin/cybra_evo_guard.py" status 2>&1 | tee -a "$LOG"

# 3. Backup перед чисткою старих бекапів
log "── 3. cleanup старих бекапів (keep 10) ──"
for dir in state/executors/backup state/executors/tag_backup state/executors/named_backup \
           state/best_pick_backup state/autofix_backup; do
  [ -d "$CYBRA/$dir" ] || continue
  N=$(ls -1 "$CYBRA/$dir"/*.tar.gz "$CYBRA/$dir"/*.sh 2>/dev/null | wc -l)
  ls -1t "$CYBRA/$dir"/*.tar.gz "$CYBRA/$dir"/*.sh 2>/dev/null | tail -n +11 | xargs -r rm -f
  log "  $dir: was $N, kept 10"
done

# 4. Cleanup старих autofix history (>30 днів)
if [ -f "$CYBRA/state/autofix_history.jsonl" ]; then
  BEFORE=$(wc -l < "$CYBRA/state/autofix_history.jsonl")
  python3 - <<'PY' 2>&1 | tee -a "$LOG"
import json, time, os
from pathlib import Path
p = Path(os.environ["HOME"]) / "CYBRA/state/autofix_history.jsonl"
cutoff = time.time() - 30*86400
kept = []
for line in p.read_text().splitlines():
    try:
        rec = json.loads(line)
        from datetime import datetime
        ts = datetime.fromisoformat(rec["ts"].replace("Z","+00:00")).timestamp()
        if ts > cutoff: kept.append(line)
    except: kept.append(line)
p.write_text("\n".join(kept) + ("\n" if kept else ""))
print(f"  autofix_history: kept {len(kept)} (dropped {p.read_text().count(chr(10))-len(kept)})")
PY
fi

# 5. Snapshot поточного стану
log "── 4. snapshot ──"
"$HOME/bin/snap-auto.sh" weekly-cleanup --force 2>&1 | tail -2 | tee -a "$LOG"

# 6. Hash seal
log "── 5. hash seal ──"
"$HOME/bin/heco" seal "WEEKLY-CLEANUP-$(date +%Y%m%d)" 2>&1 | tail -1 | tee -a "$LOG"
"$HOME/bin/heco" verify 2>&1 | tail -1 | tee -a "$LOG"

log "════ WEEKLY CLEANUP DONE ════"
