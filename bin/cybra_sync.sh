#!/data/data/com.termux/files/usr/bin/bash
# cybra_sync.sh — витягнуто з TUI (cmd_sync)
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

# ─── тіло функції cmd_sync ───

  hdr "SYNC"
  local p="${1:-all}"
  if [ "$p" = "all" ]; then
    ./scripts/prog-sync.sh a
    ./scripts/prog-sync.sh b
  else
    ./scripts/prog-sync.sh "$p"
  fi
  echo
  echo "  git branches:"
  git ls-remote --heads origin 'refs/heads/prog/*' 2>/dev/null | awk '{print "  " $2}'

# ─── кінець тіла ───

# запуск
cmd_sync "$@"
