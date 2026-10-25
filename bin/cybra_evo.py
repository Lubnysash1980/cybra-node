#!/usr/bin/env python3
"""EVO: score 160 модулів → history → restore weakest from git."""
import os, re, sys, json, subprocess, shutil, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"
MENU = MODS / "module_19_contract_tui_menu/bin/cybra_menu.sh"
HIST = CYBRA / "state/evo_scores.jsonl"
WEAK = CYBRA / "state/evo_weakest.json"
BACK = CYBRA / "state/evo_backups"
LOG  = CYBRA / "logs/evo.log"
for d in (HIST.parent, BACK, LOG.parent): d.mkdir(parents=True, exist_ok=True)

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    with open(LOG, "a") as f: f.write(f"[{t}] {m}\n")
    print(m, flush=True)

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

REAL_RE = re.compile(r'redis-cli|git --no-pager|pm2 jlist|python3 |cybra_|sqlite|curl|fidic', re.I)

def score_file(p: Path):
    if not p.exists():
        return {"score": -1, "lines": 0, "reason": "missing"}
    t = p.read_text(errors="ignore")
    lines = len(t.splitlines())
    calls = len(REAL_RE.findall(t))
    funcs = len(re.findall(r'^\w+\s*\(\)\s*\{', t, re.M))
    has_err = bool(re.search(r'\btrap\b|set -e|set -u|\|\| exit', t))
    has_log = bool(re.search(r'>\s*"\$LOG"|tee -a|log\(\)\s*\{', t))
    has_args = bool(re.search(r'\$\{?[1@#]\}?\b|getopts', t))
    s = lines/10 + calls*5 + funcs*3 + (10 if has_err else 0) + (10 if has_log else 0) + (5 if has_args else 0)
    return {"score": round(s,1), "lines": lines, "calls": calls,
            "funcs": funcs, "err": has_err, "log": has_log, "args": has_args,
            "bytes": len(t), "reason": "ok"}

def cmd_score():
    items = parse_menu()
    ts = datetime.now(timezone.utc).isoformat()
    rows, total = [], 0
    for n in range(1, 161):
        p = items.get(n)
        s = score_file(p) if p else {"score":-1,"reason":"no_wire"}
        s["n"] = n; s["ts"] = ts; s["path"] = str(p) if p else ""
        rows.append(s); total += max(0, s["score"])
    with open(HIST, "a") as f:
        for r in rows: f.write(json.dumps(r, ensure_ascii=False) + "\n")
    weakest = sorted([r for r in rows if r["score"] >= 0], key=lambda r: r["score"])[:10]
    avg = round(total/160, 1)
    WEAK.write_text(json.dumps({"ts": ts, "avg": avg, "total": round(total,1), "weakest": weakest}, indent=2))
    log(f"score: avg={avg} total={round(total,1)} weakest=[{', '.join(str(w['n']) for w in weakest[:5])}]")
    return rows

def cmd_status():
    if not HIST.exists(): print("no history — run: cybra_evo.py score"); return
    lines = HIST.read_text().splitlines()
    latest_ts = json.loads(lines[-1])["ts"]
    latest = [json.loads(l) for l in lines if json.loads(l)["ts"] == latest_ts]
    weak = json.loads(WEAK.read_text()) if WEAK.exists() else {}
    avg = round(sum(r["score"] for r in latest if r["score"]>=0)/160, 1)
    print(f"═══ EVO STATUS ═══")
    print(f"  modules:   {len(latest)}")
    print(f"  avg score: {avg}")
    print(f"  total:     {weak.get('total','?')}")
    print(f"  history:   {len(lines)} rows ({len(lines)//160} full cycles)")
    print(f"  weakest 5: {[w['n'] for w in weak.get('weakest',[])[:5]]}")
    if latest:
        print(f"\n  sample top-3 REAL:")
        top = sorted([r for r in latest if r["score"]>0], key=lambda r:-r["score"])[:3]
        for r in top: print(f"    [{r['n']:>3}] score={r['score']:<6} lines={r['lines']:<4} calls={r['calls']}")

def cmd_history():
    if not HIST.exists(): print("no history"); return
    by_cycle = {}
    for line in HIST.read_text().splitlines():
        r = json.loads(line)
        by_cycle.setdefault(r["ts"], []).append(r["score"])
    for ts in sorted(by_cycle)[-10:]:
        scores = [s for s in by_cycle[ts] if s >= 0]
        avg = round(sum(scores)/len(scores),1) if scores else 0
        print(f"  {ts}  avg={avg}  n={len(scores)}")

def cmd_weakest(n=10):
    if not WEAK.exists(): print("no scores"); return
    w = json.loads(WEAK.read_text())
    print(f"avg={w['avg']}  ts={w['ts']}")
    for r in w["weakest"][:n]:
        print(f"  [{r['n']:>3}] score={r['score']:<6} lines={r['lines']:<4} calls={r['calls']}  {r['path']}")

def git_best_for(n, current_score):
    """Шукає найкращу версію в git для модуля n."""
    rel = f"modules/module_{n:03d}_base/main.sh"
    rels = [rel]
    # альтернативні імена
    for d in MODS.glob(f"module_0*{n}_*"):
        if d.is_dir(): rels.append(f"modules/{d.name}/main.sh")
    best = None
    for relp in rels:
        r = subprocess.run(["git","log","--all","--format=%H","--",relp],
                          cwd=CYBRA, capture_output=True, text=True)
        for c in r.stdout.splitlines()[:15]:
            s = subprocess.run(["git","show",f"{c}:{relp}"],
                              cwd=CYBRA, capture_output=True, text=True)
            if s.returncode != 0 or not s.stdout: continue
            p_tmp = CYBRA / ".evo_chk.sh"
            p_tmp.write_text(s.stdout)
            if subprocess.run(["bash","-n",str(p_tmp)], capture_output=True).returncode != 0:
                p_tmp.unlink(missing_ok=True); continue
            p_tmp.unlink(missing_ok=True)
            sc = score_file(p_tmp.parent / ".evo_chk_score")  # reuse
            # manual score
            lines = len(s.stdout.splitlines())
            calls = len(REAL_RE.findall(s.stdout))
            funcs = len(re.findall(r'^\w+\s*\(\)\s*\{', s.stdout, re.M))
            has_err = bool(re.search(r'\btrap\b|set -e|set -u|\|\| exit', s.stdout))
            has_log = bool(re.search(r'>\s*"\$LOG"|tee -a|log\(\)\s*\{', s.stdout))
            has_args = bool(re.search(r'\$\{?[1@#]\}?\b|getopts', s.stdout))
            score = lines/10 + calls*5 + funcs*3 + (10 if has_err else 0) + (10 if has_log else 0) + (5 if has_args else 0)
            score = round(score, 1)
            if best is None or score > best[0]:
                best = (score, c[:8], s.stdout, relp)
    return best

def cmd_restore(max_n=5):
    if not WEAK.exists(): print("run score first"); return
    w = json.loads(WEAK.read_text())
    restored = 0
    for r in w["weakest"][:max_n]:
        n = r["n"]; cur = r["score"]; path = Path(r["path"]) if r.get("path") else None
        if not path or not path.exists():
            log(f"  [{n}] skip: no path"); continue
        best = git_best_for(n, cur)
        if not best:
            log(f"  [{n}] skip: no git history"); continue
        bscore, commit, content, relp = best
        if bscore <= cur + 10:  # поріг +10 щоб не чіпати дарма
            log(f"  [{n}] skip: best={bscore} <= cur+10={cur+10}"); continue
        # бекап
        ts = time.strftime("%Y%m%d_%H%M%S")
        bkp = BACK / f"module_{n:03d}_{ts}.sh"
        shutil.copy2(path, bkp)
        # запис
        path.write_text(content)
        os.chmod(path, 0o755)
        # verify
        if subprocess.run(["bash","-n",str(path)], capture_output=True).returncode != 0:
            shutil.copy2(bkp, path)
            log(f"  [{n}] revert: syntax broken")
            continue
        log(f"  [{n}] RESTORED: {cur} → {bscore} (git:{commit})")
        restored += 1
    log(f"cycle: restored {restored}/{min(max_n, len(w['weakest']))}")

def cmd_cycle():
    cmd_score()
    cmd_restore(max_n=5)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    arg = sys.argv[2] if len(sys.argv) > 2 else None
    if cmd == "status": cmd_status()
    elif cmd == "score": cmd_score()
    elif cmd == "history": cmd_history()
    elif cmd == "weakest": cmd_weakest(int(arg) if arg else 10)
    elif cmd == "restore": cmd_restore(int(arg) if arg else 5)
    elif cmd == "cycle": cmd_cycle()
    elif cmd == "loop":
        interval = int(arg) if arg else 600
        log(f"═══ EVO LOOP (interval={interval}s) ═══")
        while True:
            try: cmd_cycle()
            except Exception as e: log(f"ERR {e}")
            time.sleep(interval)
    else:
        print("usage: status | score | history | weakest [N] | restore [N] | cycle | loop [sec]")
