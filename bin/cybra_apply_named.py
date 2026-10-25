#!/usr/bin/env python3
import os, re, subprocess, tarfile, time, json
from pathlib import Path
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"
STUB_RE = re.compile(r'AI-INTEGRATED|потребує наповнення', re.I)

def git_show(rev, rel):
    r = subprocess.run(["git","show",f"{rev}:{rel}"], cwd=CYBRA, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 and r.stdout.strip() else None

def syntax_ok(t):
    p = CYBRA / ".chk.sh"; p.write_text(t)
    try: return subprocess.run(["bash","-n",str(p)], capture_output=True).returncode == 0
    finally: p.unlink(missing_ok=True)

# знайти пари stub-base ↔ named-real
r = subprocess.run(["git","ls-tree","-r","--name-only","v1.1-GOLDEN","--","modules/"],
                   cwd=CYBRA, capture_output=True, text=True)
golden_mains = [f for f in r.stdout.splitlines() if f.endswith("/main.sh")]

# індекс: N → [named dirs]
from collections import defaultdict
named_by_n = defaultdict(list)
for f in golden_mains:
    parts = f.split("/")
    if len(parts) < 3: continue
    name = parts[1]
    m = re.match(r"module_0*(\d+)_(.+)$", name)
    if not m: continue
    n = int(m.group(1)); suffix = m.group(2)
    if suffix in ("base", "generated"): continue
    named_by_n[n].append((name, f))

# поточні stubs
stubs = []
for d in sorted(MODS.iterdir()):
    if not d.is_dir(): continue
    m = re.match(r"module_(\d+)", d.name)
    if not m: continue
    n = int(m.group(1))
    if n > 160: continue
    main = d / "main.sh"
    if main.exists() and STUB_RE.search(main.read_text(errors="ignore")):
        stubs.append((n, d.name))

# план
plan = []
for n, dirname in stubs:
    if n not in named_by_n: continue
    for alt_name, alt_path in named_by_n[n]:
        c = git_show("v1.1-GOLDEN", alt_path)
        if not c: continue
        if STUB_RE.search(c): continue  # альтернатива теж stub — пропускаємо
        if not syntax_ok(c): continue
        if len(c) < 200: continue  # мінімум 200 байт
        plan.append({"n": n, "base_dir": dirname, "alt_name": alt_name,
                     "size": len(c), "content": c})
        break

print(f"план: {len(plan)} замін")
for p in plan[:20]:
    print(f"  [{p['n']:>3}] {p['base_dir']:<30} ← {p['alt_name']}  ({p['size']}B)")

if not plan:
    print("нічого не знайдено"); raise SystemExit

# бекап
BACKUP = CYBRA / "state/executors/named_backup"
BACKUP.mkdir(parents=True, exist_ok=True)
ts = time.strftime("%Y%m%d_%H%M%S")
bkp = BACKUP / f"before_named_{ts}.tar.gz"
with tarfile.open(bkp, "w:gz") as tar:
    for p in plan:
        tar.add(MODS / p["base_dir"], arcname=p["base_dir"])
print(f"backup: {bkp.name}")

# застосувати
for p in plan:
    dst = MODS / p["base_dir"] / "main.sh"
    dst.write_text(p["content"])
    os.chmod(dst, 0o755)

print(f"\n✅ замінено {len(plan)} модулів")

# звіт
report = {"applied": [{k:p[k] for k in ("n","alt_name","size")} for p in plan],
          "backup": str(bkp), "ts": ts}
(CYBRA / "state/executors/named_report.json").write_text(
    json.dumps(report, indent=2, ensure_ascii=False))
print(f"→ state/executors/named_report.json")
