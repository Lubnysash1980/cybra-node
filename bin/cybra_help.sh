#!/data/data/com.termux/files/usr/bin/bash
# cybra_help.sh — витягнуто з TUI (cmd_help)
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

# ─── тіло функції cmd_help ───

  printf '%b' "${B}${C}CYBRA${N} — Cyber Parliament CLI\n\n"
  printf '%b' "${B}Використання:${N}\n"
  printf '%b\n' \
    "  cybra                    → TUI меню 160 (як раніше)" \
    "  cybra help               → ця довідка" \
    "  cybra status             → 100% state, programs, pm2, git branches" \
    "  cybra parliament         → черга парламенту + останні 3 results" \
    "  cybra test [a|b]         → згенерувати програму через парламент" \
    "  cybra sync [a|b|all]     → запушити в prog/a, prog/b, або обидві" \
    "  cybra logs [name]        → pm2 logs <name> (default: parliament)" \
    "  cybra start              → підняти все (redis + pm2)" \
    "  cybra stop               → pm2 stop all" \
    "  cybra pm2                → pm2 list"
  echo
  printf '%b' "${B}Pipeline:${N}\n"
  printf '%b\n' \
    "  ai-writer.py → cybra:parliament:queue → program_writer_task_handler.sh" \
    "                → binmix_base.sh → programs/prog_X/main.sh" \
    "                → prog-sync.sh → GitHub (refs/heads/prog/X)"

# ─── кінець тіла ───

# запуск
cmd_help "$@"
