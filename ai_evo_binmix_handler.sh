#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"

FIXED=0
for f in modules/module_2[0-7][0-9]_*/main.sh; do
  [ -f "$f" ] || continue
  grep -q '\[ "\$N" -gt 0 \] &&' "$f" 2>/dev/null || continue
  python3 - "$f" <<'PY'
import sys, re
p = sys.argv[1]
t = open(p).read()
out = []
for ln in t.split('\n'):
    m = re.match(r'^(\s*)\[ "\$N" -gt 0 \] && (.+?)(\s*;;)?\s*$', ln)
    if m:
        ind, rest = m.group(1), m.group(2).rstrip(';').rstrip()
        out.append(f'{ind}if [ "$N" -gt 0 ]; then {rest}; fi')
    else:
        out.append(ln)
open(p, 'w').write('\n'.join(out))
PY
  bash -n "$f" 2>/dev/null && FIXED=$((FIXED+1))
done

# binmix реєстрація
redis-cli HSET cybra:executor:mapping binmix_base_task bin/cybra_binmix_base.sh >/dev/null 2>&1
redis-cli HSET cybra:executor:mapping binmix_mixin_task bin/cybra_binmix_mixin.py >/dev/null 2>&1

# rebuild у чергу
printf '{"topic":"r_%s"}' "$(date +%s)" | redis-cli -x rpush cybra:rebuild:queue >/dev/null 2>&1

printf '{"ok":true,"fixed_rc":%d}\n' "$FIXED"
