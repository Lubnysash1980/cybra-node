#!/data/data/com.termux/files/usr/bin/bash
# cybra_payment.sh — витягнуто з TUI (cmd_payment)
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

# ─── тіло функції cmd_payment ───

  hdr "PAYMENT SYSTEM"
  local main="modules/module_280_payment_system/main.sh"
  if [ ! -f "$main" ]; then
    echo "  → генерую module_280 через парламент..."
    local task='{"topic":"pay_init_'$(date +%s)'","type":"payment_system_task"}'
    printf '%s' "$task" | redis-cli -x rpush cybra:parliament:queue >/dev/null
    local deadline=$(( $(date +%s) + 30 ))
    while [ "$(date +%s)" -lt "$deadline" ] && [ ! -f "$main" ]; do sleep 2; done
  fi
  [ ! -f "$main" ] && { err "module_280 не створено (30s timeout)"; return 1; }
  bash "$main" "$@"

# ─── кінець тіла ───

# запуск
cmd_payment "$@"
