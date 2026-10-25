#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA"
MODS="$CYBRA/modules"
OUT="$CYBRA/state/modules_audit.json"

python3 - "$MODS" "$CYBRA" "$OUT" <<'PY'
import sys, re, json, subprocess
from pathlib import Path

mods_dir = Path(sys.argv[1]); cybra = Path(sys.argv[2]); out = Path(sys.argv[3])

STUB_MARKERS = [
    "AI-INTEGRATED", "Статус: READY", "Модуль активний",
    "Згенеровано AI", "MODULE {i}", "MODULE {}",
]
REAL_MARKERS = [
    "sqlite", "redis-cli", "curl ", "wget ",
    "cybra_contract", "cybra_invoice", "cybra_ai_",
    "python3 -c", "python3 \"", "cybra_", "_cli.sh",
    "fidic", "multisig", "ledger", "kibra",
]

def classify(text):
    size = len(text)
    lines = len(text.splitlines())
    low = text.lower()
    stub_hit = any(m.lower() in low for m in STUB_MARKERS)
    real_hit = any(m.lower() in low for m in REAL_MARKERS)
    # heuristic
    if stub_hit: return "stub"
    if size < 400 and not real_hit: return "stub"
    if real_hit or size > 1500 or lines > 40: return "real"
    return "unknown"

def find_in_git(relpath):
    """Шукає найкращу версію файлу в усій історії."""
    r = subprocess.run(["git","log","--all","--format=%H","--","modules/"+relpath],
                       cwd=cybra, capture_output=True, text=True)
    commits = [c for c in r.stdout.splitlines() if c.strip()]
    best = None  # (size, content, commit)
    for c in commits:
        s = subprocess.run(["git","show",f"{c}:modules/{relpath}"],
                           cwd=cybra, capture_output=True, text=True)
        if s.returncode != 0 or not s.stdout.strip(): continue
        content = s.stdout
        # skip if that version is also a stub
        if any(m.lower() in content.lower() for m in STUB_MARKERS): continue
        # syntax check
        p = cybra / "_tmp_chk.sh"
        p.write_text(content)
        chk = subprocess.run(["bash","-n",str(p)], capture_output=True)
        p.unlink(missing_ok=True)
        if chk.returncode != 0: continue
        if best is None or len(content) > best[0]:
            best = (len(content), content, c[:8])
    return best

result = {"total": 0, "real": [], "stub": [], "unknown": [], "restored": [], "still_stub": [], "broken_restore": []}

for d in sorted(mods_dir.iterdir()):
    if not d.is_dir() or not re.match(r'module_\d+', d.name): continue
    m = re.match(r'module_(\d+)', d.name)
    if not m: continue
    n = int(m.group(1))
    main = d / "main.sh"
    if not main.exists(): continue
    result["total"] += 1
    text = main.read_text(errors="ignore")
    cls = classify(text)
    relpath = f"{d.name}/main.sh"

    if cls == "real":
        result["real"].append(n); continue

    # try restore from git
    best = find_in_git(relpath)
    if best:
        size, content, commit = best
        main.write_text(content)
        chmod = subprocess.run(["chmod","+x",str(main)])
        chk = subprocess.run(["bash","-n",str(main)], capture_output=True)
        if chk.returncode == 0:
            result["restored"].append({"n": n, "commit": commit, "size": size, "from": len(text)})
            continue
        else:
            main.write_text(text)  # revert
            result["broken_restore"].append(n)

    if cls == "stub":
        result["stub"].append(n)
        result["still_stub"].append(n)
    else:
        result["unknown"].append(n)

out.write_text(json.dumps(result, indent=2, ensure_ascii=False))

print(f"═══ MODULE AUDIT ═══")
print(f"  total modules:  {result['total']}")
print(f"  ✅ real:        {len(result['real'])}")
print(f"  🔄 restored:    {len(result['restored'])}  (з git history)")
print(f"  ❌ still stub:  {len(result['still_stub'])}")
print(f"  ⚠️  unknown:    {len(result['unknown'])}")
print(f"  💥 restore fail:{len(result['broken_restore'])}")
print()
if result["restored"]:
    print("  Відновлено (n / commit / bytes):")
    for r in result["restored"][:15]:
        print(f"    {r['n']:>3}: {r['commit']}  {r['from']}→{r['size']}B")
    if len(result["restored"]) > 15:
        print(f"    ... +{len(result['restored'])-15} more")
print()
if result["still_stub"]:
    print(f"  Заглушки без real-версії в git (треба писати руками):")
    print(f"    {result['still_stub'][:40]}")
    if len(result['still_stub']) > 40:
        print(f"    ... +{len(result['still_stub'])-40} more")
print(f"\n→ {out}")
PY
