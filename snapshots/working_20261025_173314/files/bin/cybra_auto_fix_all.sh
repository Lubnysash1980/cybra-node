#!/data/data/com.termux/files/usr/bin/bash
# CYBRA AUTO-FIX-ALL — один прохід: env → pm2 → scan → registry → smoke-test → report
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || { echo "FATAL: no $CYBRA"; exit 1; }
REPORT="$CYBRA/logs/auto_fix_$(date +%Y%m%d_%H%M%S).log"
mkdir -p "$CYBRA/logs" "$CYBRA/state"
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$REPORT"; }

log "═══ CYBRA AUTO-FIX-ALL ═══"

# ── 1. env deps ──
log "── 1. Python deps ──"
for m in redis requests psutil; do
  python3 -c "import $m" 2>/dev/null || pip install "$m" -q 2>/dev/null && log "  ✅ $m"
done

log "── 2. Redis ──"
if ! redis-cli ping 2>/dev/null | grep -q PONG; then
  log "  DOWN → start"
  pm2 start redis-server --name redis -- --daemonize no 2>/dev/null
  sleep 3
fi
redis-cli ping 2>/dev/null | grep -q PONG && log "  ✅ PONG" || log "  ❌ still down"

log "── 3. PM2 dedupe ──"
DUPS=$(pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    from collections import Counter
    d=json.load(sys.stdin); c=Counter(p['name'] for p in d)
    print(' '.join(n for n,k in c.items() if k>1))
except: pass")
if [ -n "$DUPS" ]; then
  for n in $DUPS; do pm2 delete "$n" 2>/dev/null && log "  🗑  dup removed: $n"; done
else log "  ✅ no dups"; fi

log "── 4. cybra command ──"
if ! command -v cybra >/dev/null 2>&1; then
  ln -sf "$CYBRA/cybra" "$PREFIX/bin/cybra" 2>/dev/null && log "  ✅ symlink $PREFIX/bin/cybra"
else log "  ✅ already in PATH"; fi

log "── 5. Scan bar-menu sources ──"
CANDS=$(ls "$CYBRA"/install_*bar*.sh "$CYBRA"/*bar*menu*.sh 2>/dev/null | grep -v auto_fix)
BEST=""; BEST_CNT=0
for f in $CANDS; do
  cnt=$(grep -cE '^\s*[0-9]+\)' "$f" 2>/dev/null || echo 0)
  log "  $(basename "$f"): $cnt labels, $(wc -c <"$f")B"
  [ "$cnt" -gt "$BEST_CNT" ] && { BEST_CNT=$cnt; BEST="$f"; }
done
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
[ -f "$MENU" ] && log "  main menu: $(grep -cE '^\s*[0-9]+\)' "$MENU") handlers"
MOD_CNT=$(ls -1 "$CYBRA/modules" 2>/dev/null | grep -cE '^module_[0-9]+')
log "  modules: $MOD_CNT"
log "  best source: ${BEST:-NONE} ($BEST_CNT labels)"

log "── 6. Build registry ──"
python3 - "$BEST" "$MENU" "$CYBRA/state/bar_menu_registry.json" <<'PY' 2>&1 | tee -a "$REPORT"
import sys, re, json
from pathlib import Path
srcs = [Path(p) for p in sys.argv[1:3] if p and p != "NONE" and Path(p).exists()]
out = Path(sys.argv[3])
points = []
for src in srcs:
    text = src.read_text(errors="ignore")
    for i, line in enumerate(text.splitlines()):
        m = re.match(r'\s*(\d+)\)\s*(.*)', line)
        if not m: continue
        n = int(m.group(1))
        body = m.group(2).rstrip(';').strip()
        if not body or body.startswith('#'): continue
        points.append({"id": n, "cmd": body[:180], "src": src.name, "line": i+1})
# dedupe by id, prefer first
seen = {}
for p in points:
    seen.setdefault(p["id"], p)
final = [seen[k] for k in sorted(seen)]
out.write_text(json.dumps({
    "total": len(final),
    "id_min": final[0]["id"] if final else None,
    "id_max": final[-1]["id"] if final else None,
    "sources": [s.name for s in srcs],
    "points": final,
}, indent=2, ensure_ascii=False))
print(f"  → wrote {out}")
print(f"  → total: {len(final)} points, id range: {final[0]['id'] if final else '?'}..{final[-1]['id'] if final else '?'}")
# sample
for p in final[:5]:
    print(f"    [{p['id']}] {p['cmd'][:80]}")
PY

log "── 7. Smoke test menu-worker ──"
WORKER=$(pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    for p in json.load(sys.stdin):
        if p['pm2_env']['status']=='online' and p['name'] in ('menu-worker','parliament','cybra-monolith'):
            print(p['name']); break
except: pass")
log "  worker: ${WORKER:-NONE}"
redis-cli del cybra:menu:queue cybra:menu:results >/dev/null 2>&1
for i in 1 2 3; do
  printf '{"id":"t_%d","action":"list_contracts","contract_id":""}' "$i" \
    | redis-cli -x rpush cybra:menu:queue >/dev/null
done
sleep 8
Q=$(redis-cli llen cybra:menu:queue); R=$(redis-cli llen cybra:menu:results)
log "  queue=$Q results=$R  $( [ "$R" -gt 0 ] && echo '✅ pipeline ok' || echo '❌ worker not draining' )"

log ""
log "═══ SUMMARY ═══"
log "  report:    $REPORT"
log "  registry:  $CYBRA/state/bar_menu_registry.json"
log "  best src:  ${BEST:-NONE} ($BEST_CNT labels)"
log "  modules:   $MOD_CNT"
log "  pipeline:  $( [ "$R" -gt 0 ] && echo OK || echo BROKEN )"
