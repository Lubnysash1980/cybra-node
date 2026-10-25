#!/usr/bin/env python3
import os, re, subprocess
from pathlib import Path
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"
STUB_RE = re.compile(r'AI-INTEGRATED|потребує наповнення', re.I)

def git_show(rev, rel):
    r = subprocess.run(["git","show",f"{rev}:{rel}"], cwd=CYBRA, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 and r.stdout.strip() else None

def is_stub(t): return bool(STUB_RE.search(t))

def syntax_ok(t):
    p = CYBRA / ".chk.sh"; p.write_text(t)
    try: return subprocess.run(["bash","-n",str(p)], capture_output=True).returncode == 0
    finally: p.unlink(missing_ok=True)

# знайти всі зараз-заглушки
stubs = []
for d in sorted(MODS.iterdir()):
    if not d.is_dir(): continue
    m = re.match(r"module_(\d+)", d.name)
    if not m: continue
    n = int(m.group(1))
    if n > 160: continue
    main = d / "main.sh"
    if not main.exists(): continue
    if is_stub(main.read_text(errors="ignore")):
        stubs.append((n, d.name))

print(f"знайдено заглушок 1..160: {len(stubs)}")

# теги-джерела, пріоритет
tags = []
for t in ["v1.1-GOLDEN", "v1.0-100state-20261023"]:
    r = subprocess.run(["git","rev-parse",t], cwd=CYBRA, capture_output=True)
    if r.returncode == 0: tags.append(t)
print(f"tag sources: {tags}")

# історія комітів по modules/*/main.sh (найстаріші = найімовірніше real)
r = subprocess.run(["git","log","--all","--format=%H","--","modules/"],
                   cwd=CYBRA, capture_output=True, text=True)
commits = r.stdout.splitlines()[:50]
print(f"git commits to scan: {len(commits)}")

recovered, failed = [], []

for n, dirname in stubs:
    rel = f"modules/{dirname}/main.sh"
    best = None  # (size, content, src)

    # 1. tags
    for tag in tags:
        c = git_show(tag, rel)
        if c and not is_stub(c) and syntax_ok(c):
            if not best or len(c) > best[0]:
                best = (len(c), c, f"tag:{tag}")
            break

    # 2. git history
    if not best or best[0] < 500:
        for commit in commits:
            c = git_show(commit, rel)
            if c and not is_stub(c) and syntax_ok(c) and len(c) > 500:
                if not best or len(c) > best[0]:
                    best = (len(c), c, f"git:{commit[:8]}")
                break

    if best and best[0] >= 300:  # мінімум 300 байт щоб вважати реальним
        recovered.append({"n": n, "dir": dirname, "size": best[0], "src": best[2], "content": best[1]})
    else:
        failed.append({"n": n, "dir": dirname, "best_size": best[0] if best else 0})

# застосувати
APPLIED = CYBRA / "state/executors/tag_apply"
BACKUP = CYBRA / "state/executors/tag_backup"
APPLIED.mkdir(parents=True, exist_ok=True)
BACKUP.mkdir(parents=True, exist_ok=True)

# бекап поточних заглушок
import tarfile, time
ts = time.strftime("%Y%m%d_%H%M%S")
bkp = BACKUP / f"stubs_{ts}.tar.gz"
with tarfile.open(bkp, "w:gz") as tar:
    for r in recovered:
        tar.add(MODS / r["dir"], arcname=r["dir"])
print(f"backup: {bkp.name}")

for r in recovered:
    dst = MODS / r["dir"] / "main.sh"
    dst.write_text(r["content"])
    os.chmod(dst, 0o755)

print(f"\n✅ відновлено: {len(recovered)}")
for r in recovered[:20]:
    print(f"  [{r['n']:>3}] {r['src']:<25} {r['size']}B")

print(f"\n❌ не відновлено: {len(failed)}")
for f in failed[:20]:
    print(f"  [{f['n']:>3}] {f['dir']}  best_size={f['best_size']}")

# звіт
import json
(CYBRA / "state/executors/tag_recovery_report.json").write_text(json.dumps({
    "recovered": [{k: r[k] for k in ("n","src","size")} for r in recovered],
    "failed": failed,
    "backup": str(bkp),
}, indent=2, ensure_ascii=False))
