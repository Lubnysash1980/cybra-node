#!/usr/bin/env python3
import os, re, shutil, subprocess, time
from pathlib import Path
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS  = CYBRA / "modules"
MENU  = MODS / "module_19_contract_tui_menu/bin/cybra_menu.sh"
STUB_RE = re.compile(r'AI-INTEGRATED|потребує наповнення|МОДУЛЬ.*створено заново', re.I)
REAL_M  = ["sqlite","cybra_","_cli.sh","python3 ","redis-cli","fidic","binmix","curl "]

def is_tmpl(t): return bool(STUB_RE.search(t))
def real_score(t):
    if is_tmpl(t): return -1
    return sum(1 for m in REAL_M if m in t) * 100 + len(t) // 100

def find_entry(n):
    best = None
    for pat in [f"module_0*{n}_*", f"module_{n}_*"]:
        for d in MODS.glob(pat):
            if not d.is_dir(): continue
            for f in [d/"bin/cybra_menu.sh", d/"bin/main.sh"]:
                if f.exists():
                    sc = real_score(f.read_text(errors="ignore"))
                    if sc > 0 and (not best or sc > best[0]): best = (sc, f)
            bd = d/"bin"
            if bd.exists():
                for f in sorted(bd.glob("*.sh")):
                    if ".bak" in f.name: continue
                    try: sc = real_score(f.read_text(errors="ignore"))
                    except: continue
                    if sc > 0 and (not best or sc > best[0]): best = (sc, f)
            p = d/"main.sh"
            if p.exists():
                sc = real_score(p.read_text(errors="ignore"))
                if sc > 100 and (not best or sc > best[0]): best = (sc, p)
    return best[1] if best else None

bkp = MENU.with_suffix(MENU.suffix + f".bak.{int(time.time())}")
shutil.copy2(MENU, bkp)
print(f"backup: {bkp.name}")

lines = MENU.read_text().splitlines()
replaced, still = 0, []
new_lines = []

# catch ANY wired pattern: [N] bash ".../modules/module_NN_XXX/main.sh" ;;
wire_re = re.compile(r'(\s*)(\d+)\)\s*(bash\s+"[^"]*modules/module_0*(\d+)_[^/"]+/main\.sh"\s*;;)\s*$')

for line in lines:
    m = wire_re.match(line)
    if not m:
        new_lines.append(line); continue
    n = int(m.group(4))
    entry = find_entry(n)
    if entry:
        new_lines.append(f'{m.group(1)}{n}) bash "{entry}" ;;')
        replaced += 1
    else:
        new_lines.append(line)
        still.append(n)

# add new handlers for N with real bin/ that aren't in menu
have = set()
for ln in new_lines:
    m = re.match(r'\s*(\d+)\)', ln)
    if m: have.add(int(m.group(1)))

to_add = [(n, str(e)) for n in range(1,161) if n not in have and (e := find_entry(n))]
if to_add:
    anchor = None
    for i, ln in enumerate(new_lines):
        if re.match(r'\s*0\|q\|Q\|exit\|quit\)', ln): anchor = i; break
    if anchor is not None:
        new_lines = new_lines[:anchor] + [f'        {n}) bash "{p}" ;;' for n, p in to_add] + new_lines[anchor:]

MENU.write_text("\n".join(new_lines) + "\n")

if subprocess.run(["bash","-n",str(MENU)], capture_output=True).returncode != 0:
    shutil.copy2(bkp, MENU)
    print("❌ syntax broken → rolled back"); raise SystemExit(1)

final = sum(1 for ln in new_lines if re.match(r'\s*\d+\)', ln))
print(f"\n✅ replaced (stub → real entry): {replaced}")
print(f"✅ added (real bin/ без меню):   {len(to_add)}")
print(f"❌ still stub (нема реалізації): {len(still)}")
if still: print(f"   {still[:40]}")
print(f"\nmenu handlers total: {final}")
