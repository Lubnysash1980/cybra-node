#!/usr/bin/env python3
"""Генератор 160: part1 (SPEC) → main.sh + ctrl.sh + menu."""
import os, sys, re, json, shutil, subprocess, time
from pathlib import Path
sys.path.insert(0, str(Path.home()/"CYBRA/bin"))
from cybra_gen_part1 import SPEC_MAP, MAIN_TEMPLATE, CTRL_TEMPLATE

CYBRA  = Path(os.environ["HOME"]) / "CYBRA"
MODS   = CYBRA / "modules"
CTRL   = CYBRA / "controllers"; CTRL.mkdir(exist_ok=True)
MENU   = MODS / "module_19_contract_tui_menu/bin/cybra_menu.sh"
SPEC   = CYBRA / "state/modules_spec.json"
BACKUP = CYBRA / "state/module_backups"; BACKUP.mkdir(parents=True, exist_ok=True)

def find_mod(n):
    # prefer _base (canonical)
    for pat in [f"module_{n:03d}_base", f"module_{n}_base", f"module_0{n}_base"]:
        for d in sorted(MODS.glob(pat)):
            if d.is_dir(): return d
    # fallback: any named
    for pat in [f"module_{n:03d}_*", f"module_{n}_*", f"module_0{n}_*"]:
        for d in sorted(MODS.glob(pat)):
            if d.is_dir(): return d
    return None

def main():
    print("═══ GENERATE 160 ═══")
    ts = time.strftime("%Y%m%d_%H%M%S")
    bkp = BACKUP / f"modules_{ts}.tar.gz"
    subprocess.run(["tar","-czf",str(bkp),"-C",str(CYBRA),"modules"], capture_output=True)
    print(f"backup: {bkp.name}")

    main_ok, ctrl_ok, fail = 0, 0, 0
    ctrl_files = []

    for n in range(1, 161):
        if n not in SPEC_MAP: fail += 1; continue
        name, cat, act, cli = SPEC_MAP[n]
        d = find_mod(n)
        if not d: print(f"  [{n}] no dir"); fail += 1; continue
        m = d / "main.sh"
        m.write_text(MAIN_TEMPLATE.format(n=n, name=name, category=cat, default_action=act, cli_hint=cli))
        os.chmod(m, 0o755)
        if subprocess.run(["bash","-n",str(m)],capture_output=True).returncode == 0: main_ok += 1
        else: fail += 1; continue

        c = CTRL / f"module_{n:03d}.ctrl.sh"
        c.write_text(CTRL_TEMPLATE.format(n=n))
        os.chmod(c, 0o755)
        if subprocess.run(["bash","-n",str(c)],capture_output=True).returncode == 0:
            ctrl_ok += 1; ctrl_files.append((n, str(m), str(c)))

    print(f"✅ main.sh: {main_ok}/160  fail:{fail}")
    print(f"✅ ctrl.sh: {ctrl_ok}/160")

    # menu
    mbkp = MENU.with_suffix(MENU.suffix + f".bak.{int(time.time())}")
    shutil.copy2(MENU, mbkp)
    lines = MENU.read_text().splitlines()
    anchor = next((i for i,l in enumerate(lines) if re.match(r'^\s*0\|q\|Q\|exit\|quit\)',l)), None)
    if anchor is None: print("❌ no anchor"); return
    head = [l for l in lines[:anchor] if not re.match(r'^\s*\d+\)',l)]
    wires = [f'        {n}) "{cp}" "{mp}" ;;' for n,mp,cp in ctrl_files]
    MENU.write_text("\n".join(head + wires + lines[anchor:]) + "\n")
    if subprocess.run(["bash","-n",str(MENU)],capture_output=True).returncode != 0:
        shutil.copy2(mbkp, MENU); print("❌ menu broken, rolled back"); return
    
# ── fix human labels (не чіпає wire) ──
import re as _re, json as _json
_spec_p = CYBRA/"state/modules_spec.json"
_spec = {}
if _spec_p.exists():
    try: _spec = _json.loads(_spec_p.read_text()).get("modules", {})
    except: pass
try:
    from cybra_gen_part1 import SPEC_MAP as _SM
    for _n, _r in _SM.items():
        if str(_n) not in _spec: _spec[str(_n)] = {"name": _r[0], "category": _r[1]}
except: pass
def _lab(_n):
    _i = _spec.get(str(_n), {})
    _nm = _i.get("name") or _i.get("action") or f"Module {_n}"
    _ct = _i.get("category") or _i.get("cat") or ""
    if _re.match(r'^module_\d+$', _nm): _nm = f"Module {_n}"
    _nm = _nm.replace('_',' ').title()
    return f"{_nm}" + (f" · {_ct}" if _ct else "")
_mtxt = MENU.read_text().splitlines()
_mout = []
for _ln in _mtxt:
    if _re.match(r'^\s*\d+\)', _ln):
        _mout.append(_ln); continue
    _new, _c = _re.subn(r'"module_(\d+)_[^"]*"', lambda m: f'"{_lab(int(m.group(1)))}"', _ln)
    _mout.append(_new)
MENU.write_text("\n".join(_mout) + "\n")

print(f"✅ menu: {len(wires)} wires via ctrl")

    spec = {n:{"name":v[0],"category":v[1],"action":v[2],"cli":v[3]} for n,v in SPEC_MAP.items()}
    SPEC.write_text(json.dumps({"generated":ts,"modules":spec},indent=2,ensure_ascii=False))
    print(f"✅ spec: {SPEC}")

    # test
    print("\n── TEST 10 ──")
    ok, ff = 0, 0
    for n in [2,11,25,30,47,50,80,100,121,151]:
        d = find_mod(n)
        if not d: continue
        r = subprocess.run(["bash",str(d/"main.sh"),"list"], capture_output=True, text=True, timeout=10, input="")
        lo = len(r.stdout.splitlines())
        st = "✅" if r.returncode==0 and lo>=2 else "❌"
        print(f"  [{n:>3}] {st} rc={r.returncode} lines={lo} {r.stdout.splitlines()[0] if r.stdout else 'empty'}")
        if r.returncode==0 and lo>=2: ok+=1
        else: ff+=1
    print(f"\n✅ test: {ok}/{ok+ff}")

if __name__ == "__main__":
    main()
