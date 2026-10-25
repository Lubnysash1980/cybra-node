#!/data/data/com.termux/files/usr/bin/bash
set -u
if [ $# -ge 1 ]; then TASK="$1"; else TASK=$(cat); fi
[ -z "$TASK" ] && { echo "ERR: no task"; exit 2; }

# ── Try AI Executor first ──
AI_EXEC="$HOME/CYBRA/modules/module_19_contract_tui_menu/bin/cybra_ai_executor.sh"
if [ -x "$AI_EXEC" ]; then
  MOD_N=$(printf '%s' "$TASK" | python3 -c "import sys,json;print(json.load(sys.stdin).get('module',0))" 2>/dev/null)
  # ── Lookup from modules_spec.json first ──
  SPEC="$HOME/CYBRA/state/modules_spec.json"
  if [ -f "$SPEC" ]; then
    SPEC_INFO=$(printf '%s' "$TASK" | python3 -c "
import sys, json
try:
    task = json.load(sys.stdin)
    n = str(task.get('module', 0))
    spec = json.load(open('$SPEC'))
    mods = spec.get('modules', {})
    info = mods.get(n, {})
    name = info.get('name', '') or info.get('action', '')
    cat = info.get('category', '') or info.get('cat', '')
    if name and cat:
        print(f'{name}|{cat}')
except Exception:
    pass
" 2>/dev/null)
    if [ -n "$SPEC_INFO" ]; then
      MOD_NAME="${SPEC_INFO%|*}"
      MOD_CAT="${SPEC_INFO#*|}"
      SPEC_FOUND=1
    fi
  fi
  SPEC_FOUND="${SPEC_FOUND:-0}"

  # ── Fallback: path-based ──
  [ "$SPEC_FOUND" = "0" ] && MOD_NAME=$(printf '%s' "$TASK" | python3 -c "
import sys, json, os, re
try:
    d = json.load(sys.stdin)
except Exception:
    print('module'); sys.exit()
p = d.get('path', '')
if not p: print('module'); sys.exit()
dirname = os.path.basename(os.path.dirname(p))
m = re.match(r'module_0*(\d+)_?(.*)\$', dirname)
if m:
    n, sfx = m.group(1), m.group(2)
    if sfx in ('base', 'generated', ''):
        print('module_' + n)
    else:
        print(sfx)
else:
    print('module')
" 2>/dev/null)
  [ "$SPEC_FOUND" = "1" ] || MOD_CAT=$(printf '%s' "$TASK" | python3 -c "
import sys, json, os, re
try:
    d = json.load(sys.stdin)
except Exception:
    print('custom'); sys.exit()
p = d.get('path', '')
if not p: print('custom'); sys.exit()
dirname = os.path.basename(os.path.dirname(p))
m = re.match(r'module_0*\d+_(.+)\$', dirname)
if not m: print('custom'); sys.exit()
sfx = m.group(1)
if sfx in ('base', 'generated', ''): print('custom')
else: print(sfx.split('_')[0])
" 2>/dev/null)
  [ -z "$MOD_NAME" ] && MOD_NAME="module_$MOD_N"
  [ -z "$MOD_CAT" ] && MOD_CAT="custom"

  out=$(bash "$AI_EXEC" gen "$MOD_N" "$MOD_NAME" "$MOD_CAT" 2>&1)
  rc=$?
  printf '%s\n' "$out"
  exit $rc
fi

# Fallback: генеруємо простий шаблон напряму
python3 - "$TASK" <<'PY'
import sys, json, os
from pathlib import Path
task = json.loads(sys.argv[1])
n = task.get("module"); path = Path(task.get("path",""))
if not n or not path.parent.exists():
    print(f"ERR: module={n}"); sys.exit(1)
main = path.parent / "main.sh"
nn = f"{n:03d}"
code = f"""#!/data/data/com.termux/files/usr/bin/bash
# module_{nn}
set -u
CYBRA="${{CYBRA:-$HOME/CYBRA}}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${{1:-list}}"; shift $(( $# > 0 ? 1 : 0 ))
case "$ACTION" in
  add|create) [ $# -lt 1 ] && {{ echo "usage: $0 $ACTION <name> [val]"; exit 1; }}
              redis-cli hset "cybra:m{n}:data" "$1" "${{2:-$(date +%s)}}" >/dev/null
              echo "✅ m{n}: $1" ;;
  list|status) N=$(redis-cli hlen "cybra:m{n}:data" 2>/dev/null || echo 0)
              echo "════ module_{nn} ════"; echo "  items: $N"
              [ "$N" -gt 0 ] && redis-cli hgetall "cybra:m{n}:data" | paste - - | head -20 | sed 's/^/  /' ;;
  delete)     [ $# -lt 1 ] && exit 1
              redis-cli hdel "cybra:m{n}:data" "$1" >/dev/null
              echo "✅ deleted" ;;
  *) echo "usage: $0 add|list|delete" ;;
esac
"""
main.write_text(code); os.chmod(main, 0o755)
print(f"OK: {main}")
PY
