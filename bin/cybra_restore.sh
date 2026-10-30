#!/data/data/com.termux/files/usr/bin/bash
# cybra_restore.sh — витягнуто з TUI (cmd_restore)
# Автоматично згенеровано з /data/data/com.termux/files/usr/bin/cybra
set -uo pipefail

# ─── helpers (витягнуто з TUI) ───
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || exit 1
B="\033[1m"; G="\033[32m"; Y="\033[33m"; R="\033[31m"; C="\033[36m"; N="\033[0m"
ok(){ echo -e "${G}✅${N} $*"; }
err(){ echo -e "${R}❌${N} $*"; }
hdr(){ echo -e "\n${B}${C}═══ $* ═══${N}"; }
R(){ redis-cli "$@" 2>/dev/null; }
alive(){ pm2 describe "$1" 2>/dev/null | grep -q 'status.*online'; }

# ─── тіло функції cmd_restore ───

  hdr "RESTORE 160 MODULES (через парламент)"
  local task='{"topic":"restore_'$(date +%s)'","type":"restore_modules_task","start":1,"end":160}'
  printf '%s' "$task" | redis-cli -x rpush cybra:parliament:queue >/dev/null
  echo "  → подано в парламент, чекаю..."
  local deadline=$(( $(date +%s) + 180 ))
  while [ "$(date +%s)" -lt "$deadline" ]; do
    sleep 3
    local res=$(R lrange cybra:parliament:results 0 20 | python3 -c "
import sys,json
for line in sys.stdin:
    try:
        d=json.loads(line.strip().rstrip(','))
        if d.get('type')=='restore_modules_task':
            print(d.get('status','?'), d.get('execution',{}).get('stdout','')[:200])
    except: pass
" | head -1)
    if [ -n "$res" ]; then
      echo "  ✅ $res"
      break
    fi
  done
  echo
  local c160=0
  for d in modules/module_*; do
    local n=$(basename "$d" | sed -E 's/^module_0*([0-9]+)_.*/\1/')
    [ -n "$n" ] && [ "$n" -ge 1 ] && [ "$n" -le 160 ] 2>/dev/null && c160=$((c160+1))
  done
  echo "  модулів 1-160: $c160"
  echo "  модулів всього: $(ls -d modules/module_*/ 2>/dev/null | wc -l)"

# ─── кінець тіла ───

# запуск
cmd_restore "$@"
