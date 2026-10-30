#!/data/data/com.termux/files/usr/bin/bash
# cybra_start.sh — витягнуто з TUI (cmd_start)
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

# ─── тіло функції cmd_start ───

  hdr "START ALL"
  R ping 2>/dev/null | grep -q PONG || { pm2 start redis-server --name redis -- --daemonize no >/dev/null; sleep 2; }
  pm2 resurrect >/dev/null 2>&1
  pm2 start ecosystem.config.js >/dev/null 2>&1
  pm2 save >/dev/null 2>&1
  ok "PM2 online: $(pm2 jlist 2>/dev/null | python3 -c 'import sys,json;print(sum(1 for p in json.load(sys.stdin) if p["pm2_env"]["status"]=="online"))' 2>/dev/null || echo '?')"

# ─── кінець тіла ───

# запуск
cmd_start "$@"
