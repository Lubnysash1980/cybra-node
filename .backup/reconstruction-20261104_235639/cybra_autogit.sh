#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/autogit.log"; mkdir -p "$CYBRA/logs"
INTERVAL="${INTERVAL:-300}"; MODE="once"
[ "${1:-}" = "--daemon" ] && { MODE="daemon"; INTERVAL="${2:-300}"; }
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }
run_once(){
  git rev-parse --git-dir >/dev/null 2>&1 || return 0
  git add -A >> "$LOG" 2>&1 || { log "add fail"; return 1; }
  git diff --cached --quiet && return 0
  git commit -m "auto: $(date '+%F %T')" >> "$LOG" 2>&1 || { log "commit fail"; return 1; }
  git push >> "$LOG" 2>&1 && log "push ok" || log "push fail"
}
log "═══ AUTOGIT START ═══ mode=$MODE interval=${INTERVAL}s"
[ "$MODE" = "once" ] && { run_once; exit 0; }
while true; do run_once; sleep "$INTERVAL"; done
