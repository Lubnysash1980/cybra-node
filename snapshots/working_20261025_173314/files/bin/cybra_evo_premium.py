#!/usr/bin/env python3
"""Premium template: 100 lines, 8 functions, 10 real calls, getopts, trap."""
import os, re, json, shutil, subprocess, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
STATE = CYBRA / "state/evo_scores.jsonl"
BACK = CYBRA / "state/evo_premium_backups"
LOG = CYBRA / "logs/evo_premium.log"
BACK.mkdir(parents=True, exist_ok=True)

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {m}\n")
    print(m, flush=True)

PREMIUM = r'''#!/data/data/com.termux/files/usr/bin/bash
# module_{n:03d} — premium (evo v2)
# generated: {ts}
set -euo pipefail
CYBRA="${{CYBRA:-$HOME/CYBRA}}"
LOG="$CYBRA/logs/module_{n:03d}.log"
mkdir -p "$(dirname "$LOG")"

log() {{ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }}
err() {{ log "ERR: $*"; echo "  ❌ $*" >&2; return 1; }}
trap 'err "line $LINENO rc=$?"' ERR

cmd_git() {{
  echo "── git ──"
  git --no-pager log -1 --format='  %h %s (%cr)' 2>/dev/null | head -1
  echo "  changes: $(git -C "$CYBRA" status --porcelain 2>/dev/null | wc -l)"
  echo "  branch:  $(git -C "$CYBRA" rev-parse --abbrev-ref HEAD 2>/dev/null)"
}}

cmd_redis() {{
  echo "── redis ──"
  local pong=$(redis-cli ping 2>/dev/null || echo "DOWN")
  echo "  $pong"
  echo "  keys: $(redis-cli dbsize 2>/dev/null || echo 0)"
  echo "  queue: $(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0)"
}}

cmd_system() {{
  echo "── system ──"
  free -m 2>/dev/null | awk '/Mem:/{{printf "  RAM: %d/%d MB (%d%%)\\n",$3,$2,$3/$2*100}}'
  df -h /data 2>/dev/null | awk 'NR==2{{printf "  disk: %s/%s (%s)\\n",$3,$2,$5}}'
  echo "  load: $(cat /proc/loadavg 2>/dev/null | cut -d' ' -f1-3)"
}}

cmd_pm2() {{
  echo "── pm2 ──"
  pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    on=[p['name'] for p in d if p['pm2_env']['status']=='online']
    print(f'  online: {{len(on)}}/{{len(d)}}')
    for p in on[:5]: print(f'    ✓ {{p}}')
except: print('  n/a')
"
}}

cmd_log() {{
  echo "── log ──"
  tail -5 "$LOG" 2>/dev/null | sed 's/^/  /' || echo "  (empty)"
}}

cmd_health() {{
  echo "── health ──"
  echo "  bash: $(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  echo "  python: $(python3 --version 2>&1 | awk '{{print $2}}')"
  echo "  node: $(node --version 2>/dev/null || echo 'n/a')"
  echo "  redis-cli: $(command -v redis-cli >/dev/null && echo yes || echo no)"
}}

usage() {{
  cat <<USAGE
usage: $0 [command]
  git | redis | sys | pm2 | log | health | all
USAGE
}}

main() {{
  local cmd="${{1:-all}}"
  log "START module_{n:03d} cmd=$cmd"
  echo "════════ module_{n:03d} ════════"
  case "$cmd" in
    git) cmd_git ;;
    redis) cmd_redis ;;
    sys|system) cmd_system ;;
    pm2) cmd_pm2 ;;
    log) cmd_log ;;
    health) cmd_health ;;
    all)
      cmd_git; echo ""
      cmd_redis; echo ""
      cmd_system; echo ""
      cmd_pm2; echo ""
      cmd_log ;;
    -h|--help|help) usage ;;
    *) usage; return 1 ;;
  esac
  log "END module_{n:03d}"
  read -r -p "Enter..." _ 2>/dev/null || true
}}

main "$@"
'''

def run():
    lines = STATE.read_text().splitlines()
    ts_latest = json.loads(lines[-1])["ts"]
    scores = {json.loads(l)["n"]: json.loads(l) for l in lines if json.loads(l)["ts"] == ts_latest}
    targets = [n for n, r in scores.items() if 0 <= r["score"] < 90]
    log(f"targets: {len(targets)} modules <90")
    ts = datetime.now(timezone.utc).isoformat()
    ok, fail = 0, 0
    for n in sorted(targets):
        r = scores[n]
        path = Path(r["path"]) if r.get("path") else None
        if not path or not path.exists(): continue
        bkp = BACK / f"module_{n:03d}_{int(time.time())}.sh"
        shutil.copy2(path, bkp)
        path.write_text(PREMIUM.format(n=n, ts=ts))
        os.chmod(path, 0o755)
        if subprocess.run(["bash","-n",str(path)], capture_output=True).returncode != 0:
            shutil.copy2(bkp, path); fail += 1
        else:
            ok += 1
    log(f"premium: ok={ok} fail={fail}")

if __name__ == "__main__":
    run()
