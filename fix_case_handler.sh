#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"

FIXED=0
for f in modules/module_*/main.sh; do
  [ -f "$f" ] || continue
  bash -n "$f" 2>/dev/null && continue

  python3 - "$f" <<'PY' && FIXED=$((FIXED+1))
import sys, re
p = sys.argv[1]
lines = open(p).read().split('\n')
out, changed = [], False
for i, ln in enumerate(lines):
    m = re.match(r'^\s*if \[ "\$N" -gt 0 \]; then .+; fi\s*$', ln)
    if m:
        nxt = lines[i+1] if i+1 < len(lines) else ''
        if re.match(r'^\s*[a-zA-Z_|]+\s*\)\s*$', nxt) or nxt.strip() == 'esac':
            ln = ln.rstrip() + ' ;;'
            changed = True
    out.append(ln)
open(p, 'w').write('\n'.join(out))
sys.exit(0 if changed else 1)
PY
done

REMAIN=0
for f in modules/module_*/main.sh; do
  bash -n "$f" 2>/dev/null || REMAIN=$((REMAIN+1))
done

printf '{"ok":true,"fixed":%d,"syntax_still_bad":%d}\n' "$FIXED" "$REMAIN"
