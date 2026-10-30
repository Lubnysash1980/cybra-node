#!/data/data/com.termux/files/usr/bin/bash
# cybra_parliament.sh — витягнуто з TUI (cmd_parliament)
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

# ─── тіло функції cmd_parliament ───

  hdr "PARLIAMENT"
  echo "  queue:   $(R llen cybra:parliament:queue)"
  echo "  results: $(R llen cybra:parliament:results)"
  echo "  failed:  $(R llen cybra:parliament:failed)"
  echo
  echo "  останні 3 results:"
  R lrange cybra:parliament:results 0 2 2>/dev/null | head -3 | python3 -c '
import sys, json
for line in sys.stdin:
    s = line.strip().rstrip(",").strip()
    if not s: continue
    try:
        d = json.loads(s)
        print("    " + str(d.get("topic","?")) + ": " + str(d.get("status","?")))
    except Exception:
        pass
'

# ─── кінець тіла ───

# запуск
cmd_parliament "$@"
