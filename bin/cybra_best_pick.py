#!/usr/bin/env python3
"""BEST-PICK: для кожного пункту 1..161 знайти найкращу версію з усіх джерел."""
import os, re, json, subprocess, tarfile, tempfile, shutil, hashlib, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"
PLAN = CYBRA / "state/best_pick_plan.json"
BACKUP = CYBRA / "state/best_pick_backup"
BACKUP.mkdir(parents=True, exist_ok=True)

STUB = ["ai-integrated","потребує наповнення","створено заново","mock","todo_impl"]
REAL = ["sqlite","redis-cli","cybra_","_cli.sh","python3 ","pm2 ","git ","curl ",
        "fidic","multisig","ledger","binmix","jq ","awk "]

def is_stub(t):
    return any(m in t.lower() for m in STUB)

def score(t):
    if not t or is_stub(t): return -1
    real_c = sum(1 for m in REAL if m in t)
    if real_c == 0 and len(t) < 500: return 0
    s = real_c * 100 + min(len(t), 5000) // 10
    if t.count("\n") >= 20: s += 50
    if t.startswith("#!"): s += 10
    return s

def syntax_ok(t):
    p = CYBRA / ".bp_chk.sh"; p.write_text(t)
    try: return subprocess.run(["bash","-n",str(p)], capture_output=True).returncode == 0
    finally: p.unlink(missing_ok=True)

def git_show(rev, path):
    r = subprocess.run(["git","show",f"{rev}:{path}"], cwd=CYBRA, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 and r.stdout.strip() else None

def find_dir(n):
    if n == 161: return None
    for pat in (f"module_{n:03d}_*", f"module_{n:02d}_*", f"module_{n}_*"):
        h = sorted(MODS.glob(pat))
        if h: return h[0]
    return None

def current_content(n, d):
    if n == 161:
        f = CYBRA/"bin/cybra_taxi_events.py"
        return f.read_text(errors="ignore") if f.exists() else None
    if not d: return None
    for f in [d/"main.sh", d/"bin/main.sh"]:
        if f.exists(): return f.read_text(errors="ignore")
    return None

def git_candidates(n, d):
    out = []
    if not d: return out
    rel = f"modules/{d.name}/main.sh"
    # tags
    for tag in ("v1.1-GOLDEN","v1.0-100state-20261023"):
        c = git_show(tag, rel)
        if c and syntax_ok(c) and not is_stub(c):
            out.append({"src":f"tag:{tag}","content":c,"size":len(c),"score":score(c)})
            break
    # history (last 5 commits touching file)
    r = subprocess.run(["git","log","--all","--format=%H","-n","5","--",rel],
                       cwd=CYBRA, capture_output=True, text=True)
    for commit in r.stdout.splitlines():
        c = git_show(commit, rel)
        if c and syntax_ok(c) and not is_stub(c) and score(c) >= 200:
            out.append({"src":f"git:{commit[:8]}","content":c,"size":len(c),"score":score(c)})
            break
    return out

def snapshot_candidates(n, d):
    out = []
    if not d: return out
    snaps = sorted((CYBRA/"snapshots").glob("*.tar.gz"))[-3:]
    for tb in snaps:
        try:
            with tempfile.TemporaryDirectory() as td:
                with tarfile.open(tb,"r:gz") as tar:
                    names = [m for m in tar.getmembers() if m.name.startswith(f"modules/{d.name}/")]
                    if not names: continue
                    tar.extractall(td, members=names)
                p = Path(td)/"modules"/d.name/"main.sh"
                if p.exists():
                    c = p.read_text(errors="ignore")
                    if syntax_ok(c) and not is_stub(c) and score(c) >= 200:
                        out.append({"src":f"snap:{tb.stem[:25]}","content":c,"size":len(c),"score":score(c)})
        except Exception: pass
    return out

def best_for(n):
    d = find_dir(n)
    cur = current_content(n, d)
    cur_score = score(cur) if cur else -1
    cands = [{"src":"current","content":cur,"size":len(cur) if cur else 0,"score":cur_score}] if cur else []
    if cur_score < 200:  # scan only if current is stub/weak
        cands += git_candidates(n, d)
        if max((c["score"] for c in cands), default=-1) < 200:
            cands += snapshot_candidates(n, d)
    # dedupe
    seen=set(); uniq=[]
    for c in cands:
        if not c.get("content"): continue
        h = hashlib.sha256(c["content"].encode()).hexdigest()[:12]
        if h in seen: continue
        seen.add(h); c["hash"]=h; uniq.append(c)
    uniq.sort(key=lambda c: -c["score"])
    return uniq, d, cur_score

def apply(n, d, content, src):
    if n == 161:
        f = CYBRA/"bin/cybra_taxi_events.py"; f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(content); os.chmod(f, 0o755); return True
    if not d: return False
    main = d/"main.sh"
    if main.exists():
        shutil.copy2(main, BACKUP/f"module_{n:03d}_{int(time.time())}.sh")
    hdr = (f"#!/data/data/com.termux/files/usr/bin/bash\n"
           f"# ── BEST-PICK ──\n# module: {n}\n# src: {src}\n"
           f"# picked: {datetime.now(timezone.utc).isoformat()}\n# ────────────────\n")
    body = content
    if body.startswith("#!"):
        body = body.split("\n",1)[1] if "\n" in body else ""
    main.write_text(hdr + body); os.chmod(main, 0o755)
    # final syntax gate
    if subprocess.run(["bash","-n",str(main)], capture_output=True).returncode != 0:
        shutil.copy2(BACKUP/f"module_{n:03d}_{int(time.time())-1}.sh" if (BACKUP/f"module_{n:03d}_{int(time.time())-1}.sh").exists() else main, main)
        return False
    return True

plan = {"ts": datetime.now(timezone.utc).isoformat(), "modules": {}}
stats = {"kept":0,"improved":0,"skip":0,"fail":0}
t0 = time.time()

for n in range(1, 162):
    try:
        uniq, d, cur_score = best_for(n)
        if not uniq:
            plan["modules"][n] = {"action":"skip","reason":"no candidates"}; stats["skip"]+=1; continue
        best = uniq[0]
        if best["src"] == "current":
            plan["modules"][n] = {"action":"keep","score":cur_score,"src":"current"}; stats["kept"]+=1; continue
        if best["score"] > max(cur_score, 0) * 1.05 and best["score"] > 200:
            if apply(n, d, best["content"], best["src"]):
                plan["modules"][n] = {"action":"improved","old":cur_score,"new":best["score"],"src":best["src"],"size":best["size"]}; stats["improved"]+=1
            else:
                plan["modules"][n] = {"action":"apply_failed"}; stats["fail"]+=1
        else:
            plan["modules"][n] = {"action":"keep","cur":cur_score,"best":best["score"],"reason":"<5% better"}; stats["kept"]+=1
    except Exception as e:
        plan["modules"][n] = {"action":"error","err":str(e)}; stats["fail"]+=1
    if n % 20 == 0:
        print(f"  ... {n}/161  (elapsed {int(time.time()-t0)}s)")

PLAN.write_text(json.dumps({"stats":stats,"plan":plan}, indent=2, ensure_ascii=False))
print(f"\n═══ BEST-PICK RESULT ═══")
print(f"  kept current: {stats['kept']}")
print(f"  improved:     {stats['improved']}")
print(f"  skipped:      {stats['skip']}")
print(f"  failed:       {stats['fail']}")
print(f"  time:         {int(time.time()-t0)}s")
print(f"\n  improved list:")
for n, v in sorted(plan["modules"].items(), key=lambda x: int(x[0])):
    if v.get("action") == "improved":
        print(f"    [{n:>3}] {v['old']:>5} → {v['new']:>5}  from {v['src']}")
print(f"\n→ {PLAN}")
print(f"→ backup: {BACKUP}")
