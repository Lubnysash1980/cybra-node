#!/data/data/com.termux/files/usr/bin/bash
# cybra_fix.sh — витягнуто з TUI (cmd_fix)
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

# ─── тіло функції cmd_fix ───

  hdr "ТОЧКА ФІКСАЦІЇ"
  local cp=$(redis-cli get cybra:token:checkpoint 2>/dev/null)
  if [ -z "$cp" ]; then
    warn "checkpoint НЕ встановлено — запускаю guard"
    printf '%s' '{"topic":"guard_'$(date +%s)'","type":"token_nfc_guard_task"}'       | redis-cli -x rpush cybra:parliament:queue >/dev/null
    sleep 5
    cp=$(redis-cli get cybra:token:checkpoint 2>/dev/null)
  fi
  if [ -n "$cp" ]; then
    printf '%s' "$cp" | python3 -m json.tool 2>/dev/null | sed 's/^/  /'
    ok "точка зафіксована"
  else
    err "checkpoint не встановлено"
    local is=$(redis-cli get cybra:token:issues 2>/dev/null)
    [ -n "$is" ] && printf '%s' "$is" | python3 -m json.tool 2>/dev/null | sed 's/^/  /'
    return 1
  fi

# ─── кінець тіла ───

# запуск
cmd_fix "$@"
