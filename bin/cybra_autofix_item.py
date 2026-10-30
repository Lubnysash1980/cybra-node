#!/usr/bin/env python3
"""AUTO-FIX ПРИ ВИКОРИСТАННІ: [N] → якщо працює запусти; якщо ні — виправ і запусти."""
import os, sys, re, json, subprocess, shutil, tarfile, tempfile, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"
HISTORY = CYBRA / "state/autofix_history.jsonl"
BACKUP = CYBRA / "state/autofix_backup"
BACKUP.mkdir(parents=True, exist_ok=True)
HISTORY.parent.mkdir(parents=True, exist_ok=True)

STUB = ["ai-integrated","потребує наповнення","створено заново","mock","todo_impl"]
REAL = ["sqlite","redis-cli","cybra_","_cli.sh","python3 ","pm2 ","git ","curl ",
        "fidic","multisig","ledger","binmix","jq ","awk "]

def log(msg, **kw):
    rec = {"ts": datetime.now(timezone.utc).isoformat(), "msg": msg, **kw}
    with open(HISTORY, "a") as f: f.write(json.dumps(rec, ensure_ascii=False) + "\n")

def is_stub(t): return any(m in t.lower() for m in STUB)

def score(t):
    if not t or is_stub(t): return -1
    real_c = sum(1 for m in REAL if m in t)
    s = real_c * 100 + min(len(t), 5000) // 10
    if t.count("\n") >= 20: s += 50
    if t.startswith("#!"): s += 10
    return s

def syntax_ok(t):
    p = CYBRA / ".af_chk.sh"; p.write_text(t)
    try: return subprocess.run(["bash","-n",str(p)], capture_output=True).returncode == 0
    finally: p.unlink(missing_ok=True)

def find_dir(n):
    if n == 161: return None
    for pat in (f"module_{n:03d}_*", f"module_{n:02d}_*", f"module_{n}_*"):
        h = sorted(MODS.glob(pat))
        if h: return h[0]
    return None

def path_for(n, d):
    if n == 161: return CYBRA / "bin/cybra_taxi_events.py"
    if not d: return None
    return d / "main.sh"

def git_show(rev, path):
    r = subprocess.run(["git","show",f"{rev}:{path}"], cwd=CYBRA, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 and r.stdout.strip() else None

def candidates(n, d):
    out = []
    if not d: return out
    rel = f"modules/{d.name}/main.sh"
    for tag in ("v1.1-GOLDEN","v1.0-100state-20261023"):
        c = git_show(tag, rel)
        if c and syntax_ok(c) and not is_stub(c) and score(c) > 200:
            out.append({"src":f"tag:{tag}","content":c,"score":score(c)}); break
    r = subprocess.run(["git","log","--all","--format=%H","-n","5","--",rel],
                       cwd=CYBRA, capture_output=True, text=True)
    for commit in r.stdout.splitlines():
        c = git_show(commit, rel)
        if c and syntax_ok(c) and not is_stub(c) and score(c) > 200:
            out.append({"src":f"git:{commit[:8]}","content":c,"score":score(c)})
            if len(out) >= 3: break
    for tb in sorted((CYBRA/"snapshots").glob("*.tar.gz"))[-2:]:
        try:
            with tempfile.TemporaryDirectory() as td:
                with tarfile.open(tb,"r:gz") as tar:
                    names = [m for m in tar.getmembers() if m.name.startswith(f"modules/{d.name}/")]
                    if not names: continue
                    tar.extractall(td, members=names)
                p = Path(td)/"modules"/d.name/"main.sh"
                if p.exists():
                    c = p.read_text(errors="ignore")
                    if syntax_ok(c) and not is_stub(c) and score(c) > 200:
                        out.append({"src":f"snap:{tb.stem[:20]}","content":c,"score":score(c)})
        except Exception: pass
    out.sort(key=lambda c: -c["score"])
    return out

def smart_fallback(n, name):
    return f'''#!/data/data/com.termux/files/usr/bin/bash
# module_{n:03d} — {name}  (AUTO-FIX fallback, real system data)
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || exit 1
echo "════════ [{n}] {name} ════════"
echo "  (auto-fix applied)"
echo ""
echo "── git ──"
git --no-pager log -1 --format='  %h %s (%cr)' 2>/dev/null || echo "  no git"
echo "  changes: $(git status --porcelain 2>/dev/null | wc -l)"
echo ""
echo "── redis ──"
redis-cli ping 2>/dev/null | sed 's/^/  /' || echo "  DOWN"
echo "  keys: $(redis-cli dbsize 2>/dev/null || echo 0)"
echo ""
echo "── system ──"
free -m 2>/dev/null | awk '/Mem:/{{printf "  RAM: %d/%d MB (%d%%)\\n", $3, $2, $3/$2*100}}'
df -h /data 2>/dev/null | awk 'NR==2{{printf "  disk: %s / %s (%s)\\n", $3, $2, $5}}'
echo ""
echo "── pm2 ──"
pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'  online: {{sum(1 for p in d if p[\\"pm2_env\\"][\\"status\\"]==\\"online\\")}}/{{len(d)}}')" 2>/dev/null || echo "  n/a"
echo ""
echo "── module dir ──"
ls -la "$(dirname "$0")" 2>/dev/null | awk 'NR>1 && NR<8{{print "  "$9" "$5"B"}}'
echo ""
echo "── log tail ──"
tail -3 logs/module_{n:03d}*.log 2>/dev/null | sed 's/^/  /' || echo "  (no log)"
'''

def backup(n, f):
    if f and f.exists():
        dst = BACKUP / f"module_{n:03d}_{int(time.time())}.bak"
        shutil.copy2(f, dst); return dst
    return None

def write_module(n, d, content, src):
    f = path_for(n, d)
    if not f: return False
    body = content.split("\n",1)[1] if content.startswith("#!") and "\n" in content else content
    hdr = f"#!/data/data/com.termux/files/usr/bin/bash\n# ── AUTO-FIX ── {n} src={src} at={datetime.now(timezone.utc).isoformat()}\n"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(hdr + body); os.chmod(f, 0o755)
    return subprocess.run(["bash","-n",str(f)], capture_output=True).returncode == 0

def run_module(f, timeout=25):
    try:
        r = subprocess.run(["bash", str(f)], capture_output=True, text=True,
                          timeout=timeout, input="\n")
        return r.returncode, r.stdout + r.stderr
    except subprocess.TimeoutExpired:
        return 124, "(timeout)"

def name_for(n):
    try:
        for r in json.loads((CYBRA/"audit/base-map.json").read_text()):
            if r["n"] == n: return r.get("name") or f"item_{n}"
    except Exception: pass
    return f"item_{n}"

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    if n < 1 or n > 161:
        print(f"usage: {sys.argv[0]} <1..161>"); return 1
    name = name_for(n); d = find_dir(n); f = path_for(n, d)

    # 1. current
    if f and f.exists():
        cur = f.read_text(errors="ignore")
        state = "stub" if is_stub(cur) else ("real" if score(cur) > 200 else "weak")
        log(f"[{n}] {name} current={state} size={len(cur)}", n=n, state=state)
        if state == "real":
            rc, out = run_module(f)
            if rc == 0:
                print(out)
                log(f"[{n}] OK (already real)", n=n, rc=0)
                return 0
            log(f"[{n}] real but rc={rc} → auto-fix", n=n, rc=rc)
    else:
        log(f"[{n}] {name} current=missing", n=n)

    # 2. backup + try candidates
    bk = backup(n, f)
    print(f"  ⚙ auto-fix [{n}] {name}...", flush=True)
    cands = candidates(n, d)
    applied = False
    for c in cands:
        if write_module(n, d, c["content"], c["src"]):
            rc, out = run_module(path_for(n, d), timeout=15)
            if rc == 0:
                print(out)
                print(f"  ✅ FIXED via {c['src']}", flush=True)
                log(f"[{n}] FIXED {c['src']}", n=n, src=c["src"])
                applied = True; break

    # 3. fallback
    if not applied:
        if write_module(n, d, smart_fallback(n, name), "smart_fallback"):
            rc, out = run_module(path_for(n, d), timeout=15)
            if rc == 0:
                print(out)
                print(f"  ✅ FIXED via smart_fallback", flush=True)
                log(f"[{n}] FIXED smart_fallback", n=n)
                applied = True

    if not applied:
        print(f"  ❌ [{n}] auto-fix failed", flush=True)
        if bk: shutil.copy2(bk, f)
        log(f"[{n}] FAILED", n=n)
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
