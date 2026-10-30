#!/data/data/com.termux/files/usr/bin/bash
# ── AUTOBUILD ── module 1 src=git:8755de9c at=2026-10-30T15:37:39.546897+00:00
# module_001 — premium (evo controller)
set -euo pipefail
CYBRA="${CYBRA:-$HOME/CYBRA}"
LOG="$CYBRA/logs/module_001.log"; mkdir -p "$(dirname "$LOG")"
log() { echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }
err() { log "ERR: $*"; echo "  ❌ $*" >&2; return 1; }
trap 'err "line $LINENO rc=$?"' ERR
cmd_git() { echo "── git ──"; git --no-pager log -1 --format='  %h %s' 2>/dev/null; echo "  changes: $(git -C "$CYBRA" status --porcelain 2>/dev/null | wc -l)"; }
cmd_redis() { echo "── redis ──"; echo "  $(redis-cli ping 2>/dev/null || echo DOWN)"; echo "  keys: $(redis-cli dbsize 2>/dev/null || echo 0)"; }
cmd_system() { echo "── system ──"; free -m 2>/dev/null | awk '/Mem:/{printf "  RAM: %d/%d MB\\n",$3,$2}'; df -h /data 2>/dev/null | awk 'NR==2{printf "  disk: %s/%s\\n",$3,$2}'; }
cmd_pm2() { echo "── pm2 ──"; pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(f'  online: {sum(1 for p in d if p[\\"pm2_env\\"][\\"status\\"]==\\\"online\\\")}/{len(d)}')" 2>/dev/null || echo "  n/a"; }
usage() { echo "usage: $0 [git|redis|sys|pm2|all]"; }
main() { local cmd="${1:-all}"; log "START 001 cmd=$cmd"; echo "════ module_001 ════"; case "$cmd" in git) cmd_git;; redis) cmd_redis;; sys|system) cmd_system;; pm2) cmd_pm2;; all) cmd_git; echo ""; cmd_redis; echo ""; cmd_system; echo ""; cmd_pm2;; -h|--help) usage;; *) usage; return 1;; esac; log "END 001"; read -r -p "Enter..." _ 2>/dev/null || true; }
main "$@"
