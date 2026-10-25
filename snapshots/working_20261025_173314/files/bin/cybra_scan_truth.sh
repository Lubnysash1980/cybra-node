#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
OUT="$CYBRA/state/truth.json"

python3 - "$MENU" "$CYBRA/modules" "$OUT" <<'PY'
import sys, re, json, subprocess
from pathlib import Path

menu = Path(sys.argv[1]); mods_dir = Path(sys.argv[2]); out = Path(sys.argv[3])

# ── 1. Всі case-гілки меню (включаючи 1|2|3) ──
handlers = []
if menu.exists():
    for i, line in enumerate(menu.read_text(errors="ignore").splitlines(), 1):
        # ловимо "  151) ..." і "  1|2|q|Q) ..."
        m = re.match(r'\s*([0-9]+(?:\|[0-9A-Za-z]+)*)\)\s*(.*)', line)
        if not m: continue
        labels = m.group(1)
        body = m.group(2).rstrip(';').strip()
        if not body or body.startswith('#'): continue
        for lab in labels.split('|'):
            if lab.isdigit():
                handlers.append({"id": int(lab), "cmd": body[:150], "line": i})
# dedupe
by_id = {}
for h in handlers:
    by_id.setdefault(h["id"], h)
handlers = [by_id[k] for k in sorted(by_id)]

# ── 2. Модулі ──
mods = []
for d in sorted(mods_dir.iterdir()):
    if not d.is_dir() or not re.match(r'module_\d+', d.name): continue
    n = int(re.search(r'\d+', d.name).group())
    main = d / "main.sh"
    ok = False
    if main.exists():
        r = subprocess.run(["bash", "-n", str(main)], capture_output=True)
        ok = r.returncode == 0
    mods.append({"n": n, "dir": d.name, "has_main": main.exists(), "syntax_ok": ok})

# ── 3. Порівняння 1..160 ──
have_menu = {h["id"] for h in handlers}
have_mod  = {m["n"] for m in mods}
missing_1_160 = [i for i in range(1, 161) if i not in have_menu]
covered_by_mod = [i for i in missing_1_160 if i in have_mod]
really_missing = [i for i in missing_1_160 if i not in have_mod]

data = {
    "menu_handlers": {"count": len(handlers), "ids": sorted(have_menu), "items": handlers},
    "modules": {"count": len(mods), "with_main": sum(1 for m in mods if m["has_main"]),
                "syntax_ok": sum(1 for m in mods if m["syntax_ok"])},
    "gap_analysis_1_160": {
        "menu_covers": len(have_menu & set(range(1,161))),
        "missing_from_menu": len(missing_1_160),
        "missing_but_module_exists": len(covered_by_mod),
        "really_missing": really_missing[:30],
    },
}
out.write_text(json.dumps(data, indent=2, ensure_ascii=False))

print(f"═══ TRUTH ═══")
print(f"menu handlers: {len(handlers)}  (ids: {sorted(have_menu)[:10]}...)")
print(f"modules: {len(mods)}  (with main.sh: {data['modules']['with_main']}, syntax OK: {data['modules']['syntax_ok']})")
print(f"1..160: menu covers {len(have_menu & set(range(1,161)))}/160")
print(f"  missing from menu: {len(missing_1_160)}")
print(f"  but module exists: {len(covered_by_mod)}  → can wire menu→module")
print(f"  really missing:    {len(really_missing)}  → {really_missing[:15]}{'...' if len(really_missing)>15 else ''}")
print(f"→ {out}")
PY
