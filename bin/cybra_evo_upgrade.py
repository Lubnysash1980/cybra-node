#!/usr/bin/env python3
"""EVO UPGRADE: замінити слабкі модулі (<50) на rich-template (60 рядків)."""
import os, re, json, shutil, subprocess, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
STATE = CYBRA / "state/evo_scores.jsonl"
WEAK = CYBRA / "state/evo_weakest.json"
BACK = CYBRA / "state/evo_upgrade_backups"
LOG = CYBRA / "logs/evo_upgrade.log"
BACK.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {m}\n")
    print(m, flush=True)

RICH = r'''#!/data/data/com.termux/files/usr/bin/bash
# module_{n:03d} — rich (evo upgraded)
# generated: {ts}
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_{n:03d}.log"; mkdir -p "$(dirname "$LOG")"
log() {{ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }}
trap 'log "ERR line $LINENO rc=$?"' ERR

show_git() {{
  echo "── git ──"
  git --no-pager log -1 --format='  %h %s (%cr)' 2>/dev/null | head -1
  echo "  changes: $(git status --porcelain 2>/dev/null | wc -l)"
}}
show_redis() {{
  echo "── redis ──"
  redis-cli ping 2>/dev/null | sed 's/^/  /' || echo "  DOWN"
  redis-cli dbsize 2>/dev/null | awk '{{print "  keys: "$1}}'
}}
show_system() {{
  echo "── system ──"
  free -m 2>/dev/null | awk '/Mem:/{{printf "  RAM: %d/%d MB (%d%%)\\n",$3,$2,$3/$2*100}}'
  df -h /data 2>/dev/null | awk 'NR==2{{printf "  disk: %s/%s (%s)\\n",$3,$2,$5}}'
}}
show_pm2() {{
  echo "── pm2 ──"
  pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    on=sum(1 for p in d if p['pm2_env']['status']=='online')
    print(f'  online: {{on}}/{{len(d)}}')
except: print('  n/a')
" 2>/dev/null || echo "  n/a"
}}
show_log() {{
  echo "── log (last 3) ──"
  tail -3 "$LOG" 2>/dev/null | sed 's/^/  /' || echo "  empty"
}}

main() {{
  log "START module_{n:03d} args=$#"
  echo "════════ module_{n:03d} ════════"
  case "${{1:-all}}" in
    git) show_git ;;
    redis) show_redis ;;
    sys|system) show_system ;;
    pm2) show_pm2 ;;
    log) show_log ;;
    all|*)
      show_git; echo ""
      show_redis; echo ""
      show_system; echo ""
      show_pm2; echo ""
      show_log ;;
  esac
  log "END module_{n:03d}"
  read -r -p "Enter..." _ 2>/dev/null || true
}}
main "$@"
'''

def current_scores():
    lines = STATE.read_text().splitlines()
    ts = json.loads(lines[-1])["ts"]
    return {json.loads(l)["n"]: json.loads(l) for l in lines if json.loads(l)["ts"] == ts}

def run():
    scores = current_scores()
    ts = datetime.now(timezone.utc).isoformat()
    weak = [n for n, r in scores.items() if 0 <= r["score"] < 50]
    log(f"found {len(weak)} weak modules (<50): {sorted(weak)[:20]}{'...' if len(weak) > 20 else ''}")

    if not weak:
        log("nothing to upgrade"); return

    ok, skip, fail = [], [], []
    for n in sorted(weak):
        r = scores[n]
        path = Path(r["path"]) if r.get("path") else None
        if not path or not path.exists():
            skip.append((n, "no path")); continue

        # бекап
        bkp = BACK / f"module_{n:03d}_{int(time.time())}.sh"
        shutil.copy2(path, bkp)

        # записати rich
        content = RICH.format(n=n, ts=ts)
        path.write_text(content)
        os.chmod(path, 0o755)

        # перевірка
        if subprocess.run(["bash", "-n", str(path)], capture_output=True).returncode != 0:
            shutil.copy2(bkp, path)
            fail.append((n, "syntax")); continue

        ok.append((n, r["score"], "→~100"))

    log(f"RESULT: upgraded={len(ok)} skipped={len(skip)} failed={len(fail)}")
    if ok:
        log(f"  sample upgraded: {[o[0] for o in ok[:10]]}")
    if fail:
        log(f"  failed: {fail[:10]}")

if __name__ == "__main__":
    run()
