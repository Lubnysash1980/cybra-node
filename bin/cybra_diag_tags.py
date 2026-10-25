#!/usr/bin/env python3
import os, re, subprocess
from pathlib import Path
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"
STUB_RE = re.compile(r'AI-INTEGRATED|потребує наповнення', re.I)

def git_show(rev, rel):
    r = subprocess.run(["git","show",f"{rev}:{rel}"], cwd=CYBRA, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 and r.stdout.strip() else None

# 1. Всі файли в GOLDEN під modules/*/main.sh
r = subprocess.run(["git","ls-tree","-r","--name-only","v1.1-GOLDEN","--","modules/"],
                   cwd=CYBRA, capture_output=True, text=True)
golden_files = set(r.stdout.splitlines())
print(f"GOLDEN total files under modules/: {len(golden_files)}")
golden_mains = sorted(f for f in golden_files if f.endswith("/main.sh"))
print(f"  of them main.sh: {len(golden_mains)}")

# 2. Список зараз-заглушок
stubs = []
for d in sorted(MODS.iterdir()):
    if not d.is_dir(): continue
    m = re.match(r"module_(\d+)", d.name)
    if not m: continue
    n = int(m.group(1))
    if n > 160: continue
    main = d / "main.sh"
    if not main.exists(): continue
    if STUB_RE.search(main.read_text(errors="ignore")):
        stubs.append((n, d.name))
print(f"\ncurrent stubs 1..160: {len(stubs)}")

# 3. Розподіл: що є в GOLDEN
categories = {"GOLDEN_real": [], "GOLDEN_stub": [], "GOLDEN_missing": []}
for n, dirname in stubs:
    rel = f"modules/{dirname}/main.sh"
    c = git_show("v1.1-GOLDEN", rel)
    if c is None:
        categories["GOLDEN_missing"].append(n)
    elif STUB_RE.search(c):
        categories["GOLDEN_stub"].append(n)
    else:
        categories["GOLDEN_real"].append(n)

print("\n╔═══ РОЗПОДІЛ 49 stubs ═══╗")
for k, v in categories.items():
    print(f"  {k}: {len(v)}")
    if v: print(f"    {v[:20]}{'...' if len(v)>20 else ''}")

# 4. Що є named modules в GOLDEN (для порівняння)?
named = sorted(set(
    f.split("/")[1] for f in golden_mains
    if not re.match(r"module_\d+_base$", f.split("/")[1])
    and not re.match(r"module_\d+_generated$", f.split("/")[1])
))
print(f"\nnamed modules in GOLDEN (не _base/_generated): {len(named)}")
for x in named[:20]: print(f"  {x}")

# 5. А які stubs мають named-аналог в GOLDEN? (напр. 15_base → 15_? )
print(f"\n── пошук named-версій для stubs ──")
found_replacement = {}
for n, dirname in stubs:
    if n in categories["GOLDEN_missing"] or n in categories["GOLDEN_stub"]:
        # шукаємо module_{n}_XXX де XXX != base/generated
        for f in golden_mains:
            parts = f.split("/")
            if len(parts) < 3: continue
            m = re.match(rf"module_0*{n}_(.+)$", parts[1])
            if m and m.group(1) not in ("base", "generated"):
                found_replacement[n] = (parts[1], f)
                break

print(f"  знайдено альтернативних імен: {len(found_replacement)}")
for n, (name, path) in sorted(found_replacement.items())[:20]:
    lines = (git_show("v1.1-GOLDEN", path) or "").count("\n")
    print(f"    [{n:>3}] → {name} ({lines} lines)")

# 6. Звіт
import json
(CYBRA / "state/executors/diag_tags.json").write_text(json.dumps({
    "golden_mains_total": len(golden_mains),
    "stubs_now": len(stubs),
    "categories": categories,
    "alternative_names": {str(k): v[0] for k, v in found_replacement.items()},
}, indent=2, ensure_ascii=False))
print(f"\n→ state/executors/diag_tags.json")
