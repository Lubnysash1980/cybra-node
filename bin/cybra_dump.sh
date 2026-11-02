#!/data/data/com.termux/files/usr/bin/bash
# cybra_dump.sh — створити дамп + score (для auto-restore вибору кращого).
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date +%Y%m%d_%H%M%S)
D="$CYBRA/dumps/dump_$TS"
mkdir -p "$D/state" "$D/config"

pm2 save --force >/dev/null 2>&1
cp ~/.pm2/dump.pm2 "$D/pm2.dump" 2>/dev/null
pm2 jlist > "$D/pm2.jlist.json" 2>/dev/null
jq '[.[] | {
  name, script: .pm2_env.pm_exec_path, cwd: .pm2_env.pm_cwd,
  interpreter: .pm2_env.exec_interpreter, args: .pm2_env.args,
  max_mem: .pm2_env.max_memory_restart, status: .pm2_env.status,
  restarts: .pm2_env.restart_time
}]' "$D/pm2.jlist.json" > "$D/pm2.restore.json" 2>/dev/null

for f in manifest.json stage.json golden_gate.json menu_state.json cybra.level; do
  cp "$CYBRA/state/$f" "$D/state/" 2>/dev/null
done
ls -t "$CYBRA"/node/best_*.json 2>/dev/null | head -1 | xargs -r -I{} cp {} "$D/state/best_snapshot.json"
[ -f "$CYBRA/api/run.sh" ] && cp "$CYBRA/api/run.sh" "$D/config/api_run.sh"
crontab -l > "$D/config/crontab.txt" 2>/dev/null

find "$CYBRA/bin" -maxdepth 2 -type f \( -name "*.py" -o -name "*.sh" \) 2>/dev/null | \
  sed "s|$CYBRA/||" | sort > "$D/inventory_bin.txt"
find "$CYBRA/api" -maxdepth 1 -type f 2>/dev/null | sed "s|$CYBRA/||" | sort > "$D/inventory_api.txt"

# ── SCORE: скільки online + stage + % manifest ──
TOT=$(jq 'length' "$D/pm2.jlist.json" 2>/dev/null || echo 0)
ON=$(jq '[.[]|select(.pm2_env.status=="online")]|length' "$D/pm2.jlist.json" 2>/dev/null || echo 0)
ERR=$(jq '[.[]|select(.pm2_env.status=="errored")]|length' "$D/pm2.jlist.json" 2>/dev/null || echo 0)
STG=$(jq -r '.stage // 0' "$CYBRA/state/stage.json" 2>/dev/null || echo 0)
COL=$(jq -r '.overall.color // "black"' "$CYBRA/state/manifest.json" 2>/dev/null || echo black)
PCT=$(jq -r '.overall.percent // 0' "$CYBRA/state/manifest.json" 2>/dev/null || echo 0)

# score: stage*100 + pct - errored*50 (max ~600)
SCORE=$(( STG*100 + ${PCT%.*} - ERR*50 ))

cat > "$D/MANIFEST.json" <<M
{
  "ts": "$TS",
  "score": $SCORE,
  "stage": $STG,
  "color": "$COL",
  "percent": $PCT,
  "processes": $TOT,
  "online": $ON,
  "errored": $ERR,
  "pm2_version": "$(pm2 --version 2>/dev/null)",
  "node_version": "$(node --version 2>/dev/null)",
  "python_version": "$(python3 --version 2>/dev/null)"
}
M

cd "$CYBRA/dumps"
tar czf "dump_$TS.tar.gz" "dump_$TS"

# ── ротація: тримати РІВНО 3 найкращих (не 3 найновіших) ──
# сортуємо всі дампи за score, лишаємо топ-3
python3 - "$CYBRA/dumps" <<'PY'
import json, sys, shutil
from pathlib import Path
d = Path(sys.argv[1])
items = []
for mf in d.glob("dump_*/MANIFEST.json"):
    try:
        m = json.loads(mf.read_text())
        items.append((m.get("score",0), m.get("ts",""), mf.parent))
    except Exception:
        pass
items.sort(reverse=True)  # найкращі зверху
keep = items[:3]
for sc, ts, p in items[3:]:
    shutil.rmtree(p, ignore_errors=True)
    tgz = d/f"{p.name}.tar.gz"
    if tgz.exists(): tgz.unlink()
# symlink latest → найкращий
if keep:
    latest = d/"latest"
    if latest.is_symlink() or latest.exists(): latest.unlink()
    latest.symlink_to(keep[0][2])
    (d/".best").write_text(keep[0][2].name)
print(f"kept {len(keep)} dumps, best={keep[0][2].name} score={keep[0][0]}" if keep else "no dumps")
PY

SIZE=$(du -sh "$CYBRA/dumps/dump_$TS.tar.gz" 2>/dev/null | cut -f1)
echo "[$(date +%H:%M:%S)] dump_$TS ($SIZE) score=$SCORE stage=$STG ${ON}/${TOT}online ${ERR}err"
