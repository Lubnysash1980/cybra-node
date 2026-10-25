#!/usr/bin/env python3
"""EVO CONTROLLER — єдиний мозок еволюції 160 модулів.
   Цикл: score → decide → upgrade/restore → verify → lock/rollback.
"""
import os, re, sys, json, subprocess, shutil, time, tarfile
from pathlib import Path
from datetime import datetime, timezone

CYBRA    = Path(os.environ["HOME"]) / "CYBRA"
MENU     = CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
STATE    = CYBRA / "state"
HIST     = STATE / "evo_scores.jsonl"
BASELINE = STATE / "evo_baseline.json"
LOCK     = STATE / "evo.lock"
BACKUP   = STATE / "evo_backups"
WEAK     = STATE / "evo_weakest.json"
LOG      = CYBRA / "logs/evo_controller.log"

for d in (STATE, BACKUP, LOG.parent): d.mkdir(parents=True, exist_ok=True)

# ─── конфіг ───
CFG = {
    "threshold_rollback": -3.0,     # avg нижче baseline на 3% → rollback
    "threshold_lock":     +3.0,     # avg вище baseline на 3% → новий baseline
    "weak_score":         90,       # модулі з score < 90 → кандидати на upgrade
    "upgrade_max":        10,       # за цикл покращуємо не більше N модулів
    "restore_min_delta":  10,       # restore, якщо best > current + 10
    "loop_interval":      600,      # 10 хв між циклами
    "mode":               "score-only",   # auto | score-only | upgrade-only | restore-only
}

REAL_RE = re.compile(r'redis-cli|git --no-pager|pm2 jlist|python3 |cybra_|sqlite|curl|fidic', re.I)
STUB_RE = re.compile(r'AI-INTEGRATED|потребує наповнення|smart-stub v1|МОДУЛЬ.*створено заново', re.I)

# ─── шаблон premium ───
PREMIUM = r'''#!/data/data/com.termux/files/usr/bin/bash
# module_{n:03d} — premium (evo controller)
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
  echo "  $(redis-cli ping 2>/dev/null || echo DOWN)"
  echo "  keys:  $(redis-cli dbsize 2>/dev/null || echo 0)"
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
  echo "  bash:    $(bash --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  echo "  python:  $(python3 --version 2>&1 | awk '{{print $2}}')"
  echo "  redis:   $(command -v redis-cli >/dev/null && echo yes || echo no)"
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
    all) cmd_git; echo ""; cmd_redis; echo ""; cmd_system; echo ""; cmd_pm2; echo ""; cmd_log ;;
    -h|--help|help) usage ;;
    *) usage; return 1 ;;
  esac
  log "END module_{n:03d}"
  read -r -p "Enter..." _ 2>/dev/null || true
}}
main "$@"
'''

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{t}] {m}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

def now(): return datetime.now(timezone.utc).isoformat()

# ─── SCORE ───
def parse_menu():
    items = {}
    for line in MENU.read_text(errors="ignore").splitlines():
        m = re.match(r'\s*(\d+)\)\s*(.+)', line)
        if not m: continue
        n = int(m.group(1))
        if n < 1 or n > 160: continue
        pm = re.search(r'"(/data/[^"]+\.sh)"', line)
        if pm: items[n] = Path(pm.group(1))
    return items

def score_file(p):
    if not p or not p.exists():
        return {"score": -1, "lines": 0, "reason": "missing"}
    t = p.read_text(errors="ignore")
    lines = len(t.splitlines())
    calls = len(REAL_RE.findall(t))
    funcs = len(re.findall(r'^\w+\s*\(\)\s*\{', t, re.M))
    has_err = bool(re.search(r'\btrap\b|set -e|set -u|\|\| exit', t))
    has_log = bool(re.search(r'>\s*"\$LOG"|tee -a|log\(\)\s*\{', t))
    has_args = bool(re.search(r'\$\{?[1@#]\}?\b|getopts|case\s+"\$\{?1', t))
    s = lines/10 + calls*5 + funcs*3 + (10 if has_err else 0) + (10 if has_log else 0) + (5 if has_args else 0)
    return {"score": round(s,1), "lines": lines, "calls": calls, "funcs": funcs}

def do_score():
    items = parse_menu()
    ts = now()
    rows, total = [], 0
    for n in range(1, 161):
        p = items.get(n)
        s = score_file(p) if p else {"score": -1, "reason": "no_wire"}
        s.update({"n": n, "ts": ts, "path": str(p) if p else ""})
        rows.append(s); total += max(0, s["score"])
    avg = round(total/160, 2)
    with open(HIST, "a") as f:
        for r in rows: f.write(json.dumps(r, ensure_ascii=False) + "\n")
    weak = sorted([r for r in rows if 0 <= r["score"] < CFG["weak_score"]], key=lambda r: r["score"])
    WEAK.write_text(json.dumps({"ts": ts, "avg": avg, "total": round(total,1),
                                "weakest": weak[:20]}, indent=2, ensure_ascii=False))
    return avg, rows, weak

# ─── BASELINE ───
def load_baseline():
    if not BASELINE.exists(): return None
    try: return json.loads(BASELINE.read_text())
    except: return None

def snapshot_modules(tag):
    bkp = BACKUP / f"modules_{tag}_{int(time.time())}.tar.gz"
    subprocess.run(["tar","-czf",str(bkp),"-C",str(CYBRA),"modules"], check=False)
    return bkp

def save_baseline(avg, rows, reason):
    bkp = snapshot_modules("baseline")
    BASE = {"locked_at": now(), "avg": avg, "reason": reason, "snapshot": str(bkp),
            "modules": {str(r["n"]): {"score": r["score"], "path": r.get("path","")} for r in rows}}
    BASELINE.write_text(json.dumps(BASE, indent=2, ensure_ascii=False))
    return bkp

def rollback():
    b = load_baseline()
    if not b or not Path(b["snapshot"]).exists():
        log("  ❌ rollback: no baseline snapshot"); return False
    log(f"  🚨 rollback from {Path(b['snapshot']).name}")
    subprocess.run(["tar","-xzf",b["snapshot"],"-C",str(CYBRA)], check=False)
    return True

# ─── UPGRADE / RESTORE ───
def cmd_git_best(n, cur):
    rels = [f"modules/module_{n:03d}_base/main.sh"]
    for d in (CYBRA/"modules").glob(f"module_0*{n}_*"):
        if d.is_dir(): rels.append(f"modules/{d.name}/main.sh")
    best = None
    for rel in rels:
        r = subprocess.run(["git","log","--all","--format=%H","--",rel],
                           cwd=CYBRA, capture_output=True, text=True)
        for c in r.stdout.splitlines()[:15]:
            s = subprocess.run(["git","show",f"{c}:{rel}"],
                               cwd=CYBRA, capture_output=True, text=True)
            if s.returncode != 0 or not s.stdout: continue
            tmp = STATE / ".evo_chk.sh"; tmp.write_text(s.stdout)
            ok = subprocess.run(["bash","-n",str(tmp)], capture_output=True).returncode == 0
            tmp.unlink(missing_ok=True)
            if not ok: continue
            lines = len(s.stdout.splitlines())
            calls = len(REAL_RE.findall(s.stdout))
            funcs = len(re.findall(r'^\w+\s*\(\)\s*\{', s.stdout, re.M))
            has_err = bool(re.search(r'\btrap\b|set -e|set -u|\|\| exit', s.stdout))
            has_log = bool(re.search(r'>\s*"\$LOG"|tee -a|log\(\)\s*\{', s.stdout))
            has_args = bool(re.search(r'\$\{?[1@#]\}?\b|getopts|case\s+"\$\{?1', s.stdout))
            sc = lines/10 + calls*5 + funcs*3 + (10 if has_err else 0) + (10 if has_log else 0) + (5 if has_args else 0)
            sc = round(sc, 1)
            if best is None or sc > best[0]:
                best = (sc, c[:8], s.stdout, rel)
    return best

def try_upgrade(n, path):
    if not path.exists(): return False
    bkp = BACKUP / f"up_{n:03d}_{int(time.time())}.sh"
    shutil.copy2(path, bkp)
    path.write_text(PREMIUM.format(n=n, ts=now()))
    os.chmod(path, 0o755)
    if subprocess.run(["bash","-n",str(path)], capture_output=True).returncode != 0:
        shutil.copy2(bkp, path); return False
    return True

def try_restore(n, path, cur):
    best = cmd_git_best(n, cur)
    if not best: return False
    bsc, commit, content, rel = best
    if bsc <= cur + CFG["restore_min_delta"]: return False
    bkp = BACKUP / f"rs_{n:03d}_{int(time.time())}.sh"
    shutil.copy2(path, bkp)
    path.write_text(content); os.chmod(path, 0o755)
    if subprocess.run(["bash","-n",str(path)], capture_output=True).returncode != 0:
        shutil.copy2(bkp, path); return False
    log(f"    [{n}] restored {cur} → {bsc} (git:{commit})")
    return True

# ─── CYCLE ───
def cycle():
    if LOCK.exists():
        log("cycle: lock present, skip"); return
    LOCK.touch()
    try:
        log("═══ EVO CYCLE ═══")
        avg, rows, weak = do_score()
        base = load_baseline()
        if not base:
            bkp = save_baseline(avg, rows, "initial")
            log(f"  baseline INIT: avg={avg} snapshot={bkp.name}")
            return

        delta = avg - base["avg"]
        log(f"  score: avg={avg} baseline={base['avg']} delta={delta:+.2f}%")

        # ROLLBACK
        if delta <= CFG["threshold_rollback"]:
            log(f"  🚨 DEGRADATION {delta:+.2f}%")
            if rollback():
                avg2, rows2, _ = do_score()
                save_baseline(avg2, rows2, f"after_rollback_from_{delta:+.2f}%")
                log(f"  baseline reset post-rollback: avg={avg2}")
            return

        # UPGRADE weak
        if CFG["mode"] in ("auto", "upgrade-only") and weak:
            upgraded = 0
            for r in weak[:CFG["upgrade_max"]]:
                p = Path(r["path"]) if r.get("path") else None
                if p and p.exists() and try_upgrade(r["n"], p):
                    upgraded += 1
            if upgraded:
                avg2, rows2, _ = do_score()
                log(f"  upgraded {upgraded} modules: avg={avg} → {avg2}")
                delta = avg2 - base["avg"]
                avg, rows = avg2, rows2

        # RESTORE
        if CFG["mode"] in ("auto", "restore-only") and weak:
            restored = 0
            for r in weak[:CFG["upgrade_max"]]:
                p = Path(r["path"]) if r.get("path") else None
                if p and p.exists() and try_restore(r["n"], p, r["score"]):
                    restored += 1
            if restored:
                avg2, rows2, _ = do_score()
                log(f"  restored {restored} from git: avg={avg} → {avg2}")
                avg, rows = avg2, rows2

        # LOCK new baseline
        if delta >= CFG["threshold_lock"]:
            bkp = save_baseline(avg, rows, f"evolution_{delta:+.2f}%")
            log(f"  🚀 LOCK baseline {base['avg']} → {avg} snapshot={bkp.name}")

        WEAK.write_text(json.dumps({"ts": now(), "avg": avg,
                                    "weakest": [{k: r[k] for k in ("n","score","path")}
                                                for r in sorted([r for r in rows if 0<=r["score"]<CFG["weak_score"]],
                                                                key=lambda r: r["score"])[:20]]},
                                   indent=2, ensure_ascii=False))
    finally:
        LOCK.unlink(missing_ok=True)

# ─── CLI ───
def cmd_status():
    base = load_baseline()
    if not HIST.exists():
        print("no history"); return
    lines = HIST.read_text().splitlines()
    ts = json.loads(lines[-1])["ts"]
    cur = [json.loads(l) for l in lines if json.loads(l)["ts"] == ts]
    avg = round(sum(r["score"] for r in cur if r["score"]>=0)/160, 2)
    print("═══ EVO CONTROLLER STATUS ═══")
    print(f"  current avg: {avg}")
    if base:
        d = avg - base["avg"]
        print(f"  baseline:    {base['avg']}  (locked {base['locked_at']})")
        print(f"  delta:       {d:+.2f}%  [{CFG['threshold_rollback']:+.0f}% rollback | {CFG['threshold_lock']:+.0f}% lock]")
    else:
        print("  baseline:    NONE")
    print(f"  history:     {len(lines)//160} cycles")
    print(f"  threshold:   weak<{CFG['weak_score']}, upgrade_max={CFG['upgrade_max']}")
    print(f"  mode:        {CFG['mode']}")
    w = json.loads(WEAK.read_text()) if WEAK.exists() else {"weakest": []}
    if w["weakest"]:
        print(f"  weakest 5:   {[x['n'] for x in w['weakest'][:5]]}")

def cmd_history():
    if not HIST.exists(): print("no history"); return
    by = {}
    for l in HIST.read_text().splitlines():
        r = json.loads(l); by.setdefault(r["ts"], []).append(r["score"])
    for ts in sorted(by)[-12:]:
        s = [x for x in by[ts] if x >= 0]
        print(f"  {ts}  avg={round(sum(s)/len(s),2) if s else 0}  n={len(s)}")

def cmd_rollback():
    if rollback():
        avg, rows, _ = do_score()
        save_baseline(avg, rows, "manual_rollback")
        log(f"manual rollback → avg={avg}")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status": cmd_status()
    elif cmd == "history": cmd_history()
    elif cmd == "cycle": cycle()
    elif cmd == "rollback": cmd_rollback()
    elif cmd == "loop":
        i = int(sys.argv[2]) if len(sys.argv) > 2 else CFG["loop_interval"]
        log(f"═══ EVO CONTROLLER LOOP (interval={i}s, mode={CFG['mode']}) ═══")
        while True:
            try: cycle()
            except Exception as e: log(f"ERR {e}")
            time.sleep(i)
    else:
        print("usage: status | history | cycle | rollback | loop [sec]")
