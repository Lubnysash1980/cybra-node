#!/data/data/com.termux/files/usr/bin/bash
# cybra_guard.sh — витягнуто з TUI (cmd_guard)
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

# ─── тіло функції cmd_guard ───

  hdr "GUARD (ручна перевірка)"
  printf '%s' '{"topic":"guard_'$(date +%s)'","type":"token_nfc_guard_task"}'     | redis-cli -x rpush cybra:parliament:queue >/dev/null
  sleep 5
  local r=$(redis-cli lrange cybra:parliament:results 0 0)
  printf '%s' "$r" | python3 -c "
import sys,json
try:
    d=json.loads(sys.stdin.read().strip().strip(chr(34)))
    ex=d.get('execution',{})
    print('  status:', d.get('status'))
    print('  output:', ex.get('stdout','').strip() or ex.get('stderr','').strip())
except Exception as e:
    print('  raw:', sys.stdin.read()[:300])
"

# ─── кінець тіла ───

# запуск
cmd_guard "$@"
