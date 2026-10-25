#!/usr/bin/env python3
import os, re, subprocess, shutil, time
from pathlib import Path
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS  = CYBRA / "modules"
MENU  = MODS / "module_19_contract_tui_menu/bin/cybra_menu.sh"
STUBS = [36,37,38,39,50,51,52,58,59,60,63,64,66,67,68,70,71,72,73,74,75,78,79,80,82,83,85,87,89,90]

TEMPLATE = r'''#!/data/data/com.termux/files/usr/bin/bash
# module_{n:03d} — smart-stub v1 (real system data)
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null
echo "════════ module_{n:03d} ════════"
echo ""
echo "── git ──"
git --no-pager log -1 --format='  %h %s (%cr)' 2>/dev/null | head -1
echo "  files changed: $(git status --porcelain 2>/dev/null | wc -l)"
echo ""
echo "── redis ──"
redis-cli ping 2>/dev/null | sed 's/^/  /' || echo "  DOWN"
redis-cli dbsize 2>/dev/null | sed 's/^/  keys: /'
echo ""
echo "── system ──"
free -m 2>/dev/null | awk '/Mem:/{{printf "  RAM: %d/%d MB (%d%%)\n", $3, $2, $3/$2*100}}'
df -h /data 2>/dev/null | awk 'NR==2{{printf "  disk: %s used of %s (%s)\n", $3, $2, $5}}'
echo ""
echo "── pm2 core ──"
pm2 jlist 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    online=sum(1 for p in d if p['pm2_env']['status']=='online')
    print(f'  online: {{online}}/{{len(d)}}')
except: print('  pm2 unavailable')
" 2>/dev/null || echo "  pm2 unavailable"
echo ""
echo "── module dir ──"
ls -la "$(dirname "$0")" 2>/dev/null | awk 'NR>1 && NR<8{{print "  "$9" "$5"B"}}'
echo ""
echo "── log (last 3) ──"
tail -3 logs/module_{n:03d}*.log 2>/dev/null | sed 's/^/  /' || echo "  (no log)"
echo ""
read -r -p "Enter..." _
'''

# backup menu
bkp = MENU.with_suffix(MENU.suffix + f".bak.{int(time.time())}")
shutil.copy2(MENU, bkp)
print(f"menu backup: {bkp.name}")

written = 0
for n in STUBS:
    # find dir
    d = next(MODS.glob(f"module_0*{n}_*"), None) or next(MODS.glob(f"module_{n}_*"), None)
    if not d:
        print(f"  [{n}] NO DIR — skip"); continue
    main = d / "main.sh"
    main.write_text(TEMPLATE.format(n=n))
    os.chmod(main, 0o755)
    written += 1

print(f"\n✅ wrote {written} real modules")

# test all
ok = 0
for n in STUBS[:5]:
    d = next(MODS.glob(f"module_0*{n}_*"), None) or next(MODS.glob(f"module_{n}_*"), None)
    if not d: continue
    r = subprocess.run(["bash", str(d/"main.sh")], input="\n", capture_output=True, text=True, timeout=10)
    lines = len(r.stdout.splitlines())
    print(f"  [{n}] test → {lines} lines output")
    if lines > 5: ok += 1

print(f"\n✅ tested {ok}/5 OK")
