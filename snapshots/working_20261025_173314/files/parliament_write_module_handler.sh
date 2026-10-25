#!/data/data/com.termux/files/usr/bin/bash
set -u
if [ $# -ge 1 ]; then TASK="$1"; else TASK=$(cat); fi
[ -z "$TASK" ] && { echo "ERR: no task"; exit 2; }
PYTHONIOENCODING=utf-8 python3 - "$TASK" <<'PY'
import sys, json, os
from pathlib import Path
task = json.loads(sys.argv[1])
n = task.get("module"); path = Path(task.get("path",""))
if not n or not path.parent.exists():
    print(f"ERR: module={n}"); sys.exit(1)
main = path.parent / "main.sh"
code = f"""#!/data/data/com.termux/files/usr/bin/bash
# module_{n:03d} — real (IT Dept)
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null
echo "════════ module_{n:03d} ════════"
echo "── git ──"
git --no-pager log -1 --format='  %h %s' 2>/dev/null || echo "  no git"
echo "── redis ──"
redis-cli ping 2>/dev/null | sed 's/^/  /' || echo "  DOWN"
redis-cli dbsize 2>/dev/null | sed 's/^/  keys: /'
echo "── system ──"
free -m 2>/dev/null | awk '/Mem:/{{printf "  RAM: %d/%d MB\\n", $3, $2}}'
df -h /data 2>/dev/null | awk 'NR==2{{printf "  disk: %s / %s\\n", $3, $2}}'
echo "── pm2 ──"
pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'  online: {{sum(1 for p in d if p[\\"pm2_env\\"][\\"status\\"]==\\"online\\")}}/{{len(d)}}')" 2>/dev/null || echo "  pm2 n/a"
read -r -p "Enter..." _
"""
main.write_text(code); os.chmod(main, 0o755)
print(f"OK: {main} ({len(code)}B)")
PY
