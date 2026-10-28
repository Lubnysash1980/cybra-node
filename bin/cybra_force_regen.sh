#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date +%Y%m%d_%H%M%S)

echo "═══ FORCE REGEN ($TS) ═══"

# ─── 1. ДІАГНОСТИКА: що ЗАРАЗ у файлі vs template ───
echo ""
echo "── 1. DIAG ──"
echo "  module_148_base перші 3 рядки:"
head -3 modules/module_148_base/main.sh 2>/dev/null | sed 's/^/    /'
echo "  чи є dashboard?"
grep -c '── git ──' modules/module_148_base/main.sh 2>/dev/null || echo 0
echo "  чи є \\n literal?"
grep -c '\\\\n' modules/module_148_base/main.sh 2>/dev/null || echo 0

# ─── 2. BASH TEMPLATE (напряму, не з part1) ───
echo ""
echo "── 2. write template to tmp ──"
TPL="$HOME/CYBRA/state/cybra_main_template_$TS.sh"
cat > "$TPL" <<'TEMPLATE'
#!/data/data/com.termux/files/usr/bin/bash
# module_NNN: NAME (CAT)
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/module_NNN.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
trap 'log "ERR line $LINENO"' ERR
ACTION="${1:-list}"; shift $(( $# > 0 ? 1 : 0 ))
log "START NAME action=$ACTION"

case "$ACTION" in
  add|create|register)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name> [value]"; exit 1; fi
    VAL="${2:-$(date +%s)}"
    redis-cli hset "cybra:CAT:data" "$1" "$VAL" >/dev/null
    echo "✅ CAT: $1 = $VAL"
    ;;
  list|status|show)
    N=$(redis-cli hlen "cybra:CAT:data" 2>/dev/null || echo 0)
    echo "════ CAT (module_NNN) ════"
    echo "  items: $N"
    if [ "$N" -gt 0 ]; then
      redis-cli hgetall "cybra:CAT:data" | paste - - | head -20 | sed 's/^/  /'
    fi
    ;;
  delete|remove)
    if [ $# -lt 1 ]; then echo "usage: $0 $ACTION <name>"; exit 1; fi
    redis-cli hdel "cybra:CAT:data" "$1" >/dev/null
    echo "✅ deleted: $1"
    ;;
  *)
    echo "════ module_NNN: NAME ════"
    echo "  action: $ACTION  category: CAT"
    echo "  hint: $0 add <name> [value] | $0 list | $0 delete <name>"
    ;;
esac
rc=$?; log "DONE rc=$rc"; exit $rc
TEMPLATE
echo "  ✅ template: $TPL ($(wc -l < "$TPL") lines)"

# ─── 3. BACKUP ───
echo ""
echo "── 3. backup ──"
mkdir -p state/module_backups
tar -czf "state/module_backups/force_$TS.tar.gz" \
  modules controllers modules/module_19_contract_tui_menu/bin/cybra_menu.sh 2>/dev/null
echo "  ✅ force_$TS.tar.gz"

# ─── 4. MAP 1-160 → (name, cat) ───
python3 - <<'PY'
import sys, os, json, re
from pathlib import Path

CYBRA = Path.home()/"CYBRA"
TPL = sorted((Path.home()/"CYBRA"/"state").glob("cybra_main_template_*.sh"))[-1]
tpl = TPL.read_text()

# SPEC_MAP з part1
sys.path.insert(0, str(CYBRA/"bin"))
try:
    from cybra_gen_part1 import SPEC_MAP
except Exception as e:
    print(f"  ⚠️ part1 import error: {e}")
    SPEC_MAP = {}

# Override 153-160 (бо part1 старий)
for n, name, cat in [
    (153, "checkpoint", "system"),
    (154, "link_manager", "integrations"),
    (155, "mining_autofix", "mining"),
    (156, "chain_sync", "blockchain"),
    (157, "pool_monitor", "pool"),
    (158, "governance", "governance"),
    (159, "reports", "reports"),
    (160, "fidic_contracts", "fidic"),
]:
    SPEC_MAP[n] = (name, cat, "status", "")

# Fallback для тих, що не в SPEC_MAP
DEFAULT_NAMES = {
    127: ("crosschain", "multichain"),
    148: ("multisig_ui", "multisig"),
}

ok, fail, skipped = 0, 0, 0
for n in range(1, 161):
    if n in SPEC_MAP:
        name, cat = SPEC_MAP[n][0], SPEC_MAP[n][1]
    elif n in DEFAULT_NAMES:
        name, cat = DEFAULT_NAMES[n]
    else:
        name, cat = f"module_{n}", "custom"
        skipped += 1

    # Знайти папку (base пріоритет)
    d = None
    for pat in [f"module_{n:03d}_base", f"module_{n}_base",
                f"module_{n:03d}_{name}", f"module_{n}_{name}"]:
        for p in (CYBRA/"modules").glob(pat):
            if p.is_dir(): d = p; break
        if d: break
    if not d:
        d = CYBRA/"modules"/f"module_{n:03d}_{name}"
        d.mkdir(parents=True, exist_ok=True)

    # Підставити у template
    content = (tpl
        .replace("NNN", f"{n:03d}")
        .replace("NAME", name)
        .replace("CAT", cat))

    m = d/"main.sh"
    m.write_text(content)
    os.chmod(m, 0o755)

    # syntax check
    import subprocess
    chk = subprocess.run(["bash","-n",str(m)], capture_output=True)
    if chk.returncode != 0:
        print(f"  ❌ {n} syntax: {chk.stderr.decode()[:60]}")
        fail += 1
    else:
        ok += 1

print(f"  ✅ rewritten: {ok}/160  (fail: {fail}, skipped/custom: {skipped})")
PY

# ─── 5. VERIFY: 148, 153, 160 ───
echo ""
echo "── 5. VERIFY ──"
for n in 148 153 160; do
  d=$(find modules -maxdepth 1 -type d -name "module_${n}_*" 2>/dev/null | head -1)
  [ -z "$d" ] && continue
  echo "── $d ──"
  head -2 "$d/main.sh" | tail -1
  bash "$d/main.sh" list 2>&1 | head -3
  echo ""
done

# ─── 6. SANITY: dashboard / \n literals ───
echo "── 6. SANITY ──"
DASH=$(grep -l '── git ──' modules/module_*/main.sh 2>/dev/null | wc -l)
NLIT=$(grep -l '\\\\n' modules/module_*/main.sh 2>/dev/null | wc -l)
echo "  dashboard files: $DASH  (має бути 0)"
echo "  \\n literals:     $NLIT  (має бути 0)"

# ─── 7. REGENERATE MENU (labels + wires) ───
echo ""
echo "── 7. menu labels ──"
python3 - <<'PY'
import re, json, sys
from pathlib import Path
CYBRA = Path.home()/"CYBRA"
MENU = CYBRA/"modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

sys.path.insert(0, str(CYBRA/"bin"))
try:
    from cybra_gen_part1 import SPEC_MAP
except: SPEC_MAP = {}
for n, name, cat in [
    (153,"checkpoint","system"),(154,"link_manager","integrations"),
    (155,"mining_autofix","mining"),(156,"chain_sync","blockchain"),
    (157,"pool_monitor","pool"),(158,"governance","governance"),
    (159,"reports","reports"),(160,"fidic_contracts","fidic"),
]:
    SPEC_MAP[n] = (name, cat, "status", "")
SPEC_MAP[127] = ("crosschain","multichain","status","")
SPEC_MAP[148] = ("multisig_ui","multisig","status","")

def lab(n):
    row = SPEC_MAP.get(n)
    if not row: return f"Module {n}"
    name, cat = row[0], row[1]
    if re.match(r'^module_\d+$', name): return f"Module {n}"
    return name.replace('_',' ').title() + (f" · {cat}" if cat else "")

lines = MENU.read_text().splitlines()
out, ch = [], 0
for ln in lines:
    if re.match(r'^\s*\d+\)', ln): out.append(ln); continue
    new, c = re.subn(r'"module_(\d+)_[^"]*"', lambda m: f'"{lab(int(m.group(1)))}"', ln)
    out.append(new); ch += c
MENU.write_text("\n".join(out) + "\n")
print(f"  ✅ labels updated: {ch}")
PY

bash -n modules/module_19_contract_tui_menu/bin/cybra_menu.sh && echo "  ✅ menu syntax OK"

# ─── 8. REBUILD state ───
echo ""
echo "── 8. rebuild state ──"
rm -f state/snapshots/module_*.json
bash bin/cybra_autobuild_all.sh --state-only 2>&1 | grep -E 'MASTER|module|pm2|dart|api' | head -8

# ─── 9. COMMIT ───
echo ""
echo "── 9. commit + push ──"
git add -A
git commit -m "regen: all 160 modules forced clean (no dashboard, no \\n, human labels)" 2>&1 | head -2
git push origin main 2>&1 | tail -3

echo ""
echo "═══ DONE ═══"
echo "  next: cybra → [127] [148] [153] [160]"
