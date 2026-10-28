#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"
mkdir -p state/layers state/snapshots

# ═══ 1. Layers: відновити якщо зникли ═══
if [ ! -f state/layers/permissions.json ]; then
  cat > state/layers/permissions.json <<'P'
{
  "executors": {
    "parliament_executor_v6.py":   {"layers":["L0_sandbox","L1_read"]},
    "program_writer_task_handler": {"layers":["L0_sandbox","L1_read"]},
    "complexity_governor_handler": {"layers":["L0_sandbox","L1_read"]},
    "token_nfc_handler":           {"layers":["L1_read","L2_micro","L3_standard","L6_treasury"]},
    "token_nfc_guard_handler":     {"layers":["L1_read"]},
    "privacy_layer_handler":       {"layers":["L1_read"]},
    "fix_all_modules_handler":     {"layers":["L0_sandbox","L1_read"]},
    "evo_snapshot_handler":        {"layers":["L1_read"]},
    "complexity_fallback_handler": {"layers":["L0_sandbox","L1_read"]},
    "identity_layer_handler":      {"layers":["L0_sandbox","L1_read"]},
    "git_sync_handler":            {"layers":["L0_sandbox","L1_read"]},
    "finalize_handler":            {"layers":["L0_sandbox","L1_read"]}
  },
  "workers": {}
}
P
fi

if [ ! -f state/layers/definitions.json ]; then
  cat > state/layers/definitions.json <<'D'
{
  "layers": {
    "L0_sandbox":  {"name":"Sandbox",   "trust":0, "max_amount":"0",           "desc":"без токенів"},
    "L1_read":     {"name":"Read-only", "trust":1, "max_amount":"0",           "desc":"читання"},
    "L2_micro":    {"name":"Micro",     "trust":2, "max_amount":"10 CYBRA",    "desc":"мікро"},
    "L3_standard": {"name":"Standard",  "trust":3, "max_amount":"1000 CYBRA",  "desc":"побутові"},
    "L4_business": {"name":"Business",  "trust":4, "max_amount":"10000 CYBRA", "desc":"бізнес"},
    "L5_merchant": {"name":"Merchant",  "trust":5, "max_amount":"100000 CYBRA","desc":"мерчант"},
    "L6_treasury": {"name":"Treasury",  "trust":6, "max_amount":"unlimited",   "desc":"скарбниця"},
    "L7_owner":    {"name":"Owner",     "trust":7, "max_amount":"unlimited",   "desc":"власник"}
  }
}
D
fi

redis-cli -x set cybra:permissions:executors < state/layers/permissions.json >/dev/null
redis-cli -x set cybra:layers:definitions < state/layers/definitions.json >/dev/null

# ═══ 2. Fix [ "$N" -gt 0 ] && ... → if ...; then ...; fi (200-272) ═══
FIXED_RC=0
for f in modules/module_2[0-7][0-9]_*/main.sh; do
  [ -f "$f" ] || continue
  grep -q '\[ "\$N" -gt 0 \] &&' "$f" 2>/dev/null || continue
  python3 - "$f" <<'PY'
import sys, re
p = sys.argv[1]
t = open(p).read()
lines = []
for ln in t.split('\n'):
    m = re.match(r'^(\s*)\[ "\$N" -gt 0 \] && (.+?)(\s*;;)?\s*$', ln)
    if m:
        ind, rest = m.group(1), m.group(2).rstrip(';').rstrip()
        lines.append(f'{ind}if [ "$N" -gt 0 ]; then {rest}; fi')
    else:
        lines.append(ln)
open(p, 'w').write('\n'.join(lines))
PY
  bash -n "$f" 2>/dev/null && FIXED_RC=$((FIXED_RC+1))
done

# ═══ 3. Rebuild _master.json ═══
python3 - <<'PY'
import json, subprocess, time
from pathlib import Path
CYBRA = Path.home()/"CYBRA"
items = []
for d in sorted((CYBRA/"modules").glob("module_*")):
    m = d/"main.sh"
    if not m.exists(): continue
    try: n = int(d.name.split("_")[1])
    except: continue
    if 200 <= n <= 272:
        r = subprocess.run(["bash", str(m), "list"], capture_output=True, timeout=5, input="")
        items.append({"id": f"module_{n:03d}", "kind": "module", "ok": r.returncode == 0, "detail": f"rc={r.returncode}", "target": str(m)})
    elif 1 <= n <= 160:
        r = subprocess.run(["bash", "-n", str(m)], capture_output=True)
        items.append({"id": f"module_{n:03d}", "kind": "module", "ok": r.returncode == 0, "detail": "syntax" if r.returncode else "ok", "target": str(m)})
try:
    r = subprocess.run(["pm2","jlist"], capture_output=True, text=True)
    for p in json.loads(r.stdout):
        items.append({"id": f"pm2_{p['name']}", "kind": "pm2", "ok": p["pm2_env"]["status"]=="online", "detail": p["pm2_env"]["status"]})
except: pass

total = len(items); passed = sum(1 for i in items if i["ok"])
pct = round(passed*100/total, 1) if total else 0
bk = {}
for i in items:
    bk.setdefault(i["kind"], {"total":0,"passed":0})
    bk[i["kind"]]["total"] += 1
    if i["ok"]: bk[i["kind"]]["passed"] += 1

(CYBRA/"state/snapshots/_master.json").write_text(json.dumps({
    "ts": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime()),
    "total": total, "passed": passed, "pct": pct, "by_kind": bk, "items": items,
}, indent=2, ensure_ascii=False))
print(f"MASTER: {passed}/{total} = {pct}%")
for k,v in bk.items(): print(f"  {k:10} {v['passed']}/{v['total']}")
PY

# ═══ 4. Commit + push ═══
git merge --abort 2>/dev/null || true
git add -A 2>/dev/null || true
CHANGES=$(git diff --cached --name-only | wc -l)
PUSHED=no
if [ "$CHANGES" -gt 0 ]; then
  git -c user.email="parliament@cybra.local" -c user.name="cybra-parliament" \
    commit -m "finalize: restore layers, fix 200-272, rebuild master" >/dev/null 2>&1
fi
if git push --force-with-lease origin main >/dev/null 2>&1; then PUSHED=yes; fi

HEAD=$(git rev-parse --short HEAD)
printf '{"ok":true,"fixed_rc":%d,"staged":%d,"pushed":"%s","head":"%s"}\n' \
  "$FIXED_RC" "$CHANGES" "$PUSHED" "$HEAD"
