#!/data/data/com.termux/files/usr/bin/bash
# MASTER 100% STATE CONTROLLER — aggregate all per-item snapshots
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
MASTER="$CYBRA/state/snapshots/_master.json"
REGEN="${1:-}"

if [ "$REGEN" = "regen" ] || [ ! -f "$MASTER" ]; then
  bash "$CYBRA/bin/cybra_autobuild_all.sh" --state-only 2>&1 | tail -20
  exit $?
fi

python3 - "$MASTER" <<'PY'
import sys, json
d = json.load(open(sys.argv[1]))
pct = d.get("pct", 0)
p = d.get("passed", 0); t = d.get("total", 0)
print(f"════ 100% STATE ════")
print(f"  total:  {p}/{t} = {pct}%")
for k, v in d.get("by_kind", {}).items():
    kp = round(v['passed']*100/v['total'],1) if v['total'] else 0
    icon = "✅" if v['passed'] == v['total'] else "⚠️ "
    print(f"  {icon} {k:10} {v['passed']}/{v['total']} ({kp}%)")

failed = [i for i in d.get("items",[]) if not i.get("ok")]
if failed:
    print(f"\n  ❌ failed ({len(failed)}):")
    for i in failed[:10]: print(f"    {i['id']}: {i['detail']}")

print(f"\n  → {'🎉 100% READY' if pct == 100 else f'{pct}% — run per-ctrl to see'}")
sys.exit(0 if pct == 100 else 1)
PY
