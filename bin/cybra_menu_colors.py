#!/usr/bin/env python3
"""Перемальовує меню: real=зелений, weak=жовтий ⚠, stub/missing=темний ⏳. Handlers не чіпає."""
import os, re, json, subprocess, shutil, time
from pathlib import Path

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS  = CYBRA / "modules"
MENU  = MODS / "module_19_contract_tui_menu/bin/cybra_menu.sh"
AUDIT = CYBRA / "state/no_stub_audit.json"

STUB_M = ["ai-integrated","потребує наповнення","створено заново","mock","todo_impl"]
REAL_M = ["sqlite","redis-cli","cybra_","_cli.sh","python3 ","pm2 ","git ","curl ",
          "fidic","multisig","ledger","binmix","jq ","awk "]

def cls(n):
    if n == 161:
        f = CYBRA/"bin/cybra_taxi_events.py"
        return "real" if f.exists() and f.stat().st_size >= 500 else "missing"
    d = None
    for pat in (f"module_{n:03d}_*", f"module_{n:02d}_*", f"module_{n}_*"):
        hits = sorted(MODS.glob(pat))
        if hits: d = hits[0]; break
    if not d: return "missing"
    m = d/"main.sh"
    if not m.exists(): return "missing"
    t = m.read_text(errors="ignore"); sz = len(t); ln = t.count("\n")+1
    if any(x in t.lower() for x in STUB_M): return "stub"
    real = sum(1 for x in REAL_M if x in t)
    if sz < 200: return "stub"
    if ln >= 20 and real >= 1: return "real"
    if sz >= 200 and (ln < 20 or real == 0): return "weak"
    return "stub"

# names from base-map
base = json.loads((CYBRA/"audit/base-map.json").read_text())
by_n = {r["n"]: r for r in base}

lines = MENU.read_text().splitlines()

# знайти display-лінії (printf/echo з [N] або [%d], не case-handler, не hdr)
disp_re = re.compile(r'(printf|echo)\b.*\[\s*(?:\d+|%d|\$\{?\w+\}?)\s*\]')
def is_disp(ln):
    if not disp_re.search(ln): return False
    if re.match(r'\s*\d+\)\s', ln): return False
    if '(){' in ln or 'hdr()' in ln: return False
    return True

disp_idx = [i for i, ln in enumerate(lines) if is_disp(ln)]
if not disp_idx:
    print("❌ display-ліній не знайдено — меню не чіпаю"); raise SystemExit(1)

first, last = disp_idx[0], disp_idx[-1]
removed = len(disp_idx)

# нова кольорова секція
new_block = [
    "    # ── auto-generated colored menu (real=green, weak=yellow, stub=dim) ──",
    "    _cur_grp=\"\"",
    "    while IFS='|' read -r _n _name _cat _grp; do",
    "      [ -z \"$_n\" ] && continue",
    "      if [ \"$_grp\" != \"$_cur_grp\" ]; then",
    "        printf '\\n  ── %s ──\\n' \"$_grp\"",
    "        _cur_grp=\"$_grp\"",
    "      fi",
    "      case \"$_cat\" in",
    "        real) printf '  \\033[32m[%3d]\\033[0m %s\\n' \"$_n\" \"$_name\" ;;",
    "        weak) printf '  \\033[33m[%3d]\\033[0m %s \\u26a0\\n' \"$_n\" \"$_name\" ;;",
    "        *)    printf '  \\033[2m[%3d] %s \\u23f3\\033[0m\\n' \"$_n\" \"$_name\" ;;",
    "      esac",
    "    done <<'__MENU_COLORS__'",
]

counts = {"real":0, "weak":0, "stub":0, "missing":0}
for n in range(1, 162):
    r = by_n.get(n, {})
    name = (r.get("name") or f"item_{n}").replace("|","/").replace("\n"," ")
    grp = (r.get("cat") or "base")
    c = cls(n)
    counts[c] += 1
    new_block.append(f"{n}|{name}|{c}|{grp}")
new_block.append("__MENU_COLORS__")

# backup + splice
bkp = MENU.with_suffix(MENU.suffix + f".colorbackup.{int(time.time())}")
shutil.copy2(MENU, bkp)
new_lines = lines[:first] + new_block + lines[last+1:]
MENU.write_text("\n".join(new_lines) + "\n")

# syntax check + rollback on fail
r = subprocess.run(["bash","-n",str(MENU)], capture_output=True)
if r.returncode != 0:
    shutil.copy2(bkp, MENU)
    print(f"❌ menu syntax broken → rolled back to {bkp.name}")
    print(r.stderr.decode()[:400]); raise SystemExit(1)

# зберегти audit
AUDIT.parent.mkdir(exist_ok=True)
AUDIT.write_text(json.dumps({
    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "rule": "real=green, weak=yellow ⚠, stub/missing=dim ⏳. Real modules never overwritten with stubs.",
    "counts": counts,
    "sample": {n: cls(n) for n in (1,10,50,100,149,160,161)},
}, indent=2))

print(f"═══ MENU COLORS ═══")
print(f"  real    (зелений): {counts['real']}")
print(f"  weak    (жовтий):  {counts['weak']}")
print(f"  stub    (темний):  {counts['stub']}")
print(f"  missing (темний):  {counts['missing']}")
print(f"  removed display lines: {removed}")
print(f"  menu: {MENU.name}  (backup: {bkp.name})")
print(f"\n  Тепер: cybra → побачиш кольори.")
