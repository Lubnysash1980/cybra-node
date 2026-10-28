#!/data/data/com.termux/files/usr/bin/bash
# fix_all_modules_handler.sh — виправляє ВСІ модулі: dashboard, \n, rc=1
set -euo pipefail
cd "$HOME/CYBRA"
mkdir -p state/module_backups logs

TS=$(date +%Y%m%d_%H%M%S)
BK="state/module_backups/fixall_$TS.tar.gz"
tar -czf "$BK" modules 2>/dev/null || true

FIXED_DASH=0
FIXED_RC=0
FIXED_NL=0
BROKEN=0

# ─── 1. dashboard → реальний add/list/delete ───
for f in $(grep -l '── git ──' modules/module_*/main.sh 2>/dev/null); do
  d=$(dirname "$f")
  base=$(basename "$d")
  n=$(printf '%s' "$base" | sed -E 's/^module_0*([0-9]+)_?.*/\1/')
  case "$n" in ''|*[!0-9]*) continue ;; esac
  tag=$(printf '%s' "$base" | sed -E "s/^module_0*${n}_?//")
  [ -z "$tag" ] && tag="base"
  KEY="cybra:mod_${n}:data"

  cat > "$f" <<MODULE
#!/data/data/com.termux/files/usr/bin/bash
# module_$(printf '%03d' "$n"): ${tag}
set -u
CYBRA="\${CYBRA:-\$HOME/CYBRA}"; cd "\$CYBRA" 2>/dev/null || exit 1
LOG="\$CYBRA/logs/module_$(printf '%03d' "$n").log"; mkdir -p "\$(dirname "\$LOG")"
log(){ echo "[\$(date -u +%FT%TZ)] \$*" >> "\$LOG"; }
ACTION="\${1:-list}"; shift \$(( \$# > 0 ? 1 : 0 ))
KEY="${KEY}"
log "START action=\$ACTION"

case "\$ACTION" in
  add|create)
    [ \$# -lt 1 ] && { echo "usage: \$0 add <label> [value]"; exit 1; }
    VAL="\${2:-\$(date +%s)}"
    redis-cli hset "\$KEY" "\$1" "\$VAL" >/dev/null || { echo "FAIL"; exit 1; }
    echo "✅ \$1 = \$VAL"
    ;;
  list|status)
    N=\$(redis-cli hlen "\$KEY" 2>/dev/null || echo 0)
    echo "════ module_$(printf '%03d' "$n") (${tag}) ════"
    echo "  items: \$N"
    if [ "\$N" -gt 0 ]; then
      redis-cli hgetall "\$KEY" | paste - - | head -30 | sed 's/^/  /'
    fi
    ;;
  delete|remove|rm)
    [ \$# -lt 1 ] && { echo "usage: \$0 delete <label>"; exit 1; }
    redis-cli hdel "\$KEY" "\$1" >/dev/null
    echo "✅ deleted: \$1"
    ;;
  info)
    echo "  module: module_$(printf '%03d' "$n") (${tag})"
    echo "  key:    \$KEY"
    echo "  items:  \$(redis-cli hlen "\$KEY" 2>/dev/null || echo 0)"
    ;;
  *)
    echo "════ module_$(printf '%03d' "$n") (${tag}) ════"
    echo "  actions: add | list | delete | info"
    ;;
esac
rc=\$?; log "DONE rc=\$rc"; exit \$rc
MODULE
  chmod +x "$f"
  FIXED_DASH=$((FIXED_DASH+1))
done

# ─── 2. [ "$N" -gt 0 ] && ... → if ...; then ...; fi  (для 200-272) ───
for f in modules/module_*/main.sh; do
  [ -f "$f" ] || continue
  grep -q '\[ "\$N" -gt 0 \] &&' "$f" 2>/dev/null || continue
  # замінити: [ "$N" -gt 0 ] && CMD → if [ "$N" -gt 0 ]; then CMD; fi
  python3 - "$f" <<'PY'
import sys, re
p = sys.argv[1]
t = open(p).read()
# проста заміна у case-рядках
lines = []
for ln in t.split('\n'):
    m = re.match(r'^(\s*)\[ "\$N" -gt 0 \] && (.+)$', ln)
    if m:
        indent, rest = m.group(1), m.group(2)
        # прибрати trailing ;; або ; якщо є
        rest = re.sub(r'\s*;;\s*$', '', rest).rstrip(';').rstrip()
        lines.append(f'{indent}if [ "$N" -gt 0 ]; then {rest}; fi')
    else:
        lines.append(ln)
open(p, 'w').write('\n'.join(lines))
PY
  bash -n "$f" 2>/dev/null && FIXED_RC=$((FIXED_RC+1)) || BROKEN=$((BROKEN+1))
done

# ─── 3. \n literal → \n ───
for f in modules/module_*/main.sh; do
  [ -f "$f" ] || continue
  grep -q '\\\\n' "$f" 2>/dev/null || continue
  sed -i 's/\\\\\\\\n/\\n/g' "$f"
  bash -n "$f" 2>/dev/null && FIXED_NL=$((FIXED_NL+1))
done

# ─── 4. загальна перевірка: скільки list rc=0 ───
OK=0; FAIL=0
for f in modules/module_*/main.sh; do
  [ -f "$f" ] || continue
  if bash "$f" list >/dev/null 2>&1; then OK=$((OK+1)); else FAIL=$((FAIL+1)); fi
done

# ─── 5. mapping регенерація ───
if [ -f bin/cybra_ai_100pct_gen.py ]; then
  python3 bin/cybra_ai_100pct_gen.py 2>&1 | tail -3
fi

# ─── 6. autobuild --state-only ───
if [ -f bin/cybra_autobuild_all.sh ]; then
  bash bin/cybra_autobuild_all.sh --state-only 2>&1 | grep -E 'MASTER|module|pm2|dart|api' | head -6
fi

# ─── 7. результат ───
DASH_LEFT=$(grep -l '── git ──' modules/module_*/main.sh 2>/dev/null | wc -l)
NL_LEFT=$(grep -l '\\\\n' modules/module_*/main.sh 2>/dev/null | wc -l)

printf '{"ok":true,"fixed_dashboard":%d,"fixed_rc":%d,"fixed_nl":%d,"broken":%d,"list_ok":%d,"list_fail":%d,"dashboard_left":%d,"nl_left":%d}\n' \
  "$FIXED_DASH" "$FIXED_RC" "$FIXED_NL" "$BROKEN" "$OK" "$FAIL" "$DASH_LEFT" "$NL_LEFT"
