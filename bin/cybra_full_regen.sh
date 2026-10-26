#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date +%Y%m%d_%H%M%S)

echo "═══ FULL REGEN ($TS) ═══"

# ── 1. backup ──
mkdir -p state/module_backups
tar -czf "state/module_backups/pre_regen_$TS.tar.gz" modules controllers \
  modules/module_19_contract_tui_menu/bin/cybra_menu.sh 2>/dev/null
echo "  ✅ backup: pre_regen_$TS.tar.gz"

# ── 2. fix SPEC_MAP 153-160 ──
python3 - <<'PY'
from pathlib import Path
p = Path.home()/"CYBRA/bin/cybra_gen_part1.py"
t = p.read_text()
old = '''for n in range(153,161):
    SPEC_MAP[n] = (f"module_{n}", "custom", "status", "")'''
new = '''for n, _name, _cat in [
    (153, "checkpoint",      "system"),
    (154, "link_manager",    "integrations"),
    (155, "mining_autofix",  "mining"),
    (156, "chain_sync",      "blockchain"),
    (157, "pool_monitor",    "pool"),
    (158, "governance",      "governance"),
    (159, "reports",         "reports"),
    (160, "fidic_contracts", "fidic"),
]:
    SPEC_MAP[n] = (_name, _cat, "status", "")'''
if old in t:
    t = t.replace(old, new)
    print("  ✅ SPEC_MAP 153-160 → людські назви")
else:
    print("  ℹ️  SPEC_MAP 153-160 вже оновлено")

# fix \n literal у template (якщо є)
if '\\\\n' in t:
    t = t.replace('\\\\n', '\\n')
    print("  ✅ template: \\\\n → \\n")
p.write_text(t)
PY

# ── 3. regenerate ALL 160 modules ──
python3 - <<'PY'
import sys, os, importlib
from pathlib import Path
CYBRA = Path.home()/"CYBRA"
sys.path.insert(0, str(CYBRA/"bin"))
import cybra_gen_part1
importlib.reload(cybra_gen_part1)
from cybra_gen_part1 import SPEC_MAP, MAIN_TEMPLATE

ok, fail = 0, 0
for n in range(1, 161):
    if n not in SPEC_MAP: fail += 1; continue
    name, cat, act, cli = SPEC_MAP[n]
    d = None
    for pat in [f"module_{n:03d}_base", f"module_{n}_base",
                f"module_{n:03d}_{name}", f"module_{n}_{name}"]:
        for p in (CYBRA/"modules").glob(pat):
            if p.is_dir(): d = p; break
        if d: break
    if not d:
        d = CYBRA/"modules"/f"module_{n:03d}_{name}"
        d.mkdir(parents=True, exist_ok=True)
    m = d/"main.sh"
    m.write_text(MAIN_TEMPLATE.format(n=n, name=name, category=cat,
                                       default_action=act, cli_hint=cli))
    os.chmod(m, 0o755)
    ok += 1
print(f"  ✅ modules rewritten: {ok}/160  (fail: {fail})")
PY

# ── 4. regenerate menu (cybra_gen.py уже вставляє правильні wire + labels) ──
bash bin/cybra_gen.py 2>&1 | tail -5

# ── 5. verify sample ──
echo ""
echo "═══ verify 127, 153, 160 ═══"
for n in 127 153 160; do
  d=$(find modules -maxdepth 1 -type d -name "module_${n}_*" | head -1)
  echo "── $d ──"
  head -2 "$d/main.sh" | tail -1
  bash "$d/main.sh" list 2>&1 | head -3
  echo ""
done

# ── 6. syntax check ALL modules ──
BAD=0
for f in modules/module_*/main.sh; do
  bash -n "$f" 2>/dev/null || BAD=$((BAD+1))
done
echo "  syntax errors: $BAD"

# ── 7. sanity: no \\n literal, no dashboard ──
NLIT=$(grep -l '\\\\n' modules/module_*/main.sh 2>/dev/null | wc -l)
DASH=$(grep -l '── git ──' modules/module_*/main.sh 2>/dev/null | wc -l)
echo "  \\n literals:    $NLIT"
echo "  dashboard files: $DASH  (має бути 0 — всі через add/list/delete)"

# ── 8. re-run autobuild state (щоб snapshot оновились) ──
echo ""
echo "═══ rebuild state ═══"
rm -f state/snapshots/module_*.json
bash bin/cybra_autobuild_all.sh --state-only 2>&1 | tail -8

# ── 9. commit + push ──
echo ""
echo "═══ commit ═══"
git add -A
git commit -m "regen: all 160 modules — clean template (no dashboard, no \\n literal), human labels 153-160" 2>&1 | head -2
git push origin main 2>&1 | tail -3

echo ""
echo "═══ DONE ═══"
echo "  next: cybra  (перевір [127] [153] [160])"
