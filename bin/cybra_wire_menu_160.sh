#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
MODS="$CYBRA/modules"
BAK="$MENU.bak.$(date +%Y%m%d_%H%M%S)"
cp "$MENU" "$BAK"
echo "backup → $BAK"

python3 - "$MENU" "$MODS" <<'PY'
import sys, re, json
from pathlib import Path

menu = Path(sys.argv[1]); mods_dir = Path(sys.argv[2])
text = menu.read_text()
lines = text.splitlines()

# ── існуючі id ──
have = set()
for line in lines:
    m = re.match(r'\s*([0-9]+(?:\|[0-9A-Za-z]+)*)\)\s*(\S.*)$', line)
    if not m: continue
    for lab in m.group(1).split('|'):
        if lab.isdigit(): have.add(int(lab))

# ── знайти модуль для N ──
def find_module(n):
    for pat in (f"module_{n:03d}_*", f"module_{n}_*", f"module_{n}"):
        hits = list(mods_dir.glob(pat))
        if hits:
            d = hits[0]
            if (d / "main.sh").exists():
                return d.name
    return None

# ── згенерувати handlers 1..160 ──
missing = [n for n in range(1, 161) if n not in have]
wired, skipped = [], []
new_handler_lines = []
for n in missing:
    d = find_module(n)
    if not d:
        skipped.append(n); continue
    new_handler_lines.append(f'        {n}) bash "$HOME/CYBRA/modules/{d}/main.sh" ;;')
    wired.append({"id": n, "module": d})

if not wired:
    print("!! nothing to wire")
    sys.exit(0)

# ── вставити перед 0|q|Q|exit|quit) ──
insert_idx = None
for i, line in enumerate(lines):
    if re.match(r'\s*0\|q\|Q\|exit\|quit\)', line):
        insert_idx = i; break
if insert_idx is None:
    print("!! anchor '0|q|Q|exit|quit)' not found — abort"); sys.exit(1)

new_lines = lines[:insert_idx] + new_handler_lines + lines[insert_idx:]

# ── візуальний блок: після останнього printf з [NN], додати 5 груп ──
# знайдемо рядок де printf/echo показує [0]
visual_idx = None
for i, line in enumerate(new_lines):
    if re.search(r'\[0\]|\(0\)\s', line) and ('printf' in line or 'echo' in line):
        visual_idx = i; break

if visual_idx is not None:
    v_lines = ['    echo ""',
               '    echo "  ── 28..160: додано з модулів ──"']
    for w in wired:
        v_lines.append(
            f'    printf "  [%d] %s\\n" {w["id"]} "{w["module"]}"'
        )
    new_lines = new_lines[:visual_idx] + v_lines + new_lines[visual_idx:]
    visual_added = len(wired)
else:
    visual_added = 0

menu.write_text("\n".join(new_lines) + "\n")

report = {
    "existing_ids": sorted(have),
    "wired_count": len(wired),
    "skipped_ids": skipped,
    "visual_added": visual_added,
    "wired": wired,
}
Path(CYBRA / "state/menu_wiring.json").write_text(json.dumps(report, indent=2, ensure_ascii=False))

print(f"✅ wired {len(wired)} handlers")
print(f"   visual lines added: {visual_added}")
if skipped: print(f"   skipped (no module): {skipped}")
print(f"   report → {CYBRA}/state/menu_wiring.json")
PY

echo "── syntax check ──"
if bash -n "$MENU"; then
  echo "✅ menu syntax OK"
else
  echo "❌ BROKEN — restoring backup"
  cp "$BAK" "$MENU"
  exit 1
fi

echo ""
echo "── final count ──"
COUNT=$(grep -cE '^\s*[0-9]+\)\s' "$MENU")
echo "handlers in menu: $COUNT"
echo ""
echo "── next: спробуй запустити меню і ввести 28 (має відкрити module_28_*) ──"
