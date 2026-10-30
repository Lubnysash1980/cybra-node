#!/usr/bin/env python3
"""AUTO-BUILDER: заглушки в modules/ → реальні версії з git/snapshots → fallback."""
import os, re, json, subprocess, tarfile, tempfile, shutil, time
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"
BACKUP = CYBRA / "state/autobuilder_backup"
REPORT = CYBRA / "state/autobuilder_report.json"
BACKUP.mkdir(parents=True, exist_ok=True)

STUB = ["ai-integrated", "потребує наповнення", "створено заново", "mock", "todo_impl"]
REAL = ["sqlite", "redis-cli", "cybra_", "_cli.sh", "python3 ", "pm2 ", "git ", "curl ",
        "fidic", "multisig", "ledger", "binmix", "jq ", "awk "]

def is_stub(t):
    low = t.lower()
    return any(m in low for m in STUB) or (len(t) < 300 and not any(m in t for m in REAL))

def score(t):
    if not t or is_stub(t): return -1
    return sum(1 for m in REAL if m in t) * 100 + min(len(t), 5000) // 10 + (50 if t.count("\n") >= 20 else 0)

def syntax_ok(t):
    p = CYBRA / ".ab_chk.sh"; p.write_text(t)
    try: return subprocess.run(["bash","-n",str(p)], capture_output=True).returncode == 0
    finally: p.unlink(missing_ok=True)

def git_show(rev, path):
    r = subprocess.run(["git","show",f"{rev}:{path}"], cwd=CYBRA, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 and r.stdout.strip() else None

def name_for(n):
    try:
        for r in json.loads((CYBRA/"audit/base-map.json").read_text()):
            if r["n"] == n: return r.get("name") or f"item_{n}"
    except: pass
    return f"item_{n}"

def fallback(n, name):
    return f'''#!/data/data/com.termux/files/usr/bin/bash
# module_{n:03d} — {name}  (autobuild fallback)
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || exit 1
echo "════ [{n}] {name} ════════"
echo "── git ──"
git --no-pager log -1 --format='  %h %s (%cr)' 2>/dev/null || echo "  no git"
echo "  changes: $(git status --porcelain 2>/dev/null | wc -l)"
echo "── redis ──"
redis-cli ping 2>/dev/null | sed 's/^/  /' || echo "  DOWN"
echo "  keys: $(redis-cli dbsize 2>/dev/null || echo 0)"
echo "── system ──"
free -m 2>/dev/null | awk '/Mem:/{{printf "  RAM: %d/%d MB\\n", $3, $2}}'
df -h /data 2>/dev/null | awk 'NR==2{{print "  disk: "$5" used"}}'
echo "── pm2 ──"
pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'  online: {{sum(1 for p in d if p[\\"pm2_env\\"][\\"status\\"]==\\"online\\")}}/{{len(d)}}')" 2>/dev/null || echo "  n/a"
echo "── log ──"
tail -3 logs/module_{n:03d}*.log 2>/dev/null | sed 's/^/  /' || echo "  (no log)"
read -r -p "Enter..." _
'''

def find_candidates(n, d, cur_score):
    out = []
    if not d: return out
    rel = f"modules/{d.name}/main.sh"
    # tags
    for tag in ("v1.1-GOLDEN", "v1.0-100state-20261023"):
        c = git_show(tag, rel)
        if c and syntax_ok(c) and score(c) > cur_score + 100:
            out.append({"src": f"tag:{tag}", "content": c, "score": score(c)})
            break
    # history (5 commits)
    r = subprocess.run(["git","log","--all","--format=%H","-n","5","--",rel],
                       cwd=CYBRA, capture_output=True, text=True)
    for commit in r.stdout.splitlines():
        c = git_show(commit, rel)
        if c and syntax_ok(c) and score(c) > cur_score + 100:
            out.append({"src": f"git:{commit[:8]}", "content": c, "score": score(c)})
            break
    # snapshots (last 2)
    for tb in sorted((CYBRA/"snapshots").glob("*.tar.gz"))[-2:]:
        try:
            with tempfile.TemporaryDirectory() as td:
                with tarfile.open(tb, "r:gz") as tar:
                    names = [m for m in tar.getmembers() if m.name.startswith(f"modules/{d.name}/")]
                    if not names: continue
                    tar.extractall(td, members=names)
                p = Path(td)/"modules"/d.name/"main.sh"
                if p.exists():
                    c = p.read_text(errors="ignore")
                    if syntax_ok(c) and score(c) > cur_score + 100:
                        out.append({"src": f"snap:{tb.stem[:20]}", "content": c, "score": score(c)})
        except: pass
    out.sort(key=lambda c: -c["score"])
    return out

def write_module(n, d, content, src):
    main = d / "main.sh"
    if main.exists():
        shutil.copy2(main, BACKUP / f"module_{n:03d}_{int(time.time())}.sh")
    hdr = (f"#!/data/data/com.termux/files/usr/bin/bash\n"
           f"# ── AUTOBUILD ── module {n} src={src} at={datetime.now(timezone.utc).isoformat()}\n")
    body = content.split("\n",1)[1] if content.startswith("#!") and "\n" in content else content
    main.write_text(hdr + body); os.chmod(main, 0o755)
    return subprocess.run(["bash","-n",str(main)], capture_output=True).returncode == 0

def main():
    stubs = []
    for d in sorted(MODS.iterdir()):
        if not d.is_dir(): continue
        m = re.match(r"module_(\d+)", d.name)
        if not m: continue
        n = int(m.group(1))
        if n > 160: continue
        main_sh = d / "main.sh"
        if not main_sh.exists(): continue
        txt = main_sh.read_text(errors="ignore")
        if is_stub(txt):
            stubs.append((n, d, score(txt)))

    print(f"═══ AUTOBUILDER: {len(stubs)} stubs to process ═══")
    report = {"ts": datetime.now(timezone.utc).isoformat(),
              "initial_stubs": len(stubs),
              "improved": [], "fallback": [], "failed": []}

    for i, (n, d, cur_score) in enumerate(stubs, 1):
        name = name_for(n)
        cands = find_candidates(n, d, cur_score)
        applied = False
        if cands:
            c = cands[0]
            if write_module(n, d, c["content"], c["src"]):
                report["improved"].append({"n": n, "src": c["src"], "score": c["score"]})
                print(f"  [{i}/{len(stubs)}] [{n:>3}] IMPROVED ← {c['src']} (score {c['score']})")
                applied = True
        if not applied:
            if write_module(n, d, fallback(n, name), "fallback"):
                report["fallback"].append({"n": n})
                print(f"  [{i}/{len(stubs)}] [{n:>3}] FALLBACK")
                applied = True
        if not applied:
            report["failed"].append({"n": n})
            print(f"  [{i}/{len(stubs)}] [{n:>3}] FAILED")

    # re-check
    final_stubs = 0
    for d in sorted(MODS.iterdir()):
        if not d.is_dir(): continue
        m = re.match(r"module_(\d+)", d.name)
        if not m: continue
        n = int(m.group(1))
        if n > 160: continue
        f = d / "main.sh"
        if f.exists() and is_stub(f.read_text(errors="ignore")): final_stubs += 1

    report["final_stubs"] = final_stubs
    report["fixed"] = len(report["improved"]) + len(report["fallback"])
    REPORT.write_text(json.dumps(report, indent=2, ensure_ascii=False))

    print()
    print(f"═══ DONE ═══")
    print(f"  initial stubs: {len(stubs)}")
    print(f"  improved (git): {len(report['improved'])}")
    print(f"  fallback:      {len(report['fallback'])}")
    print(f"  failed:        {len(report['failed'])}")
    print(f"  final stubs:   {final_stubs}")
    print(f"  backup:        {BACKUP}")
    print(f"  report:        {REPORT}")

if __name__ == "__main__":
    main()
