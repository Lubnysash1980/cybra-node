#!/data/data/com.termux/files/usr/bin/bash
# cybra_autowatch.sh — супервізор: pm2 + bg_dump + autogit + autoheal + self-restart
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
PIDFILE="$CYBRA/.cache/autowatch.pid"
LOCKDIR="$CYBRA/.cache/autowatch.lock"
LOG="$CYBRA/logs/autowatch.log"
QUAR="$CYBRA/.keeper-quarantine"
mkdir -p "$CYBRA/.cache" "$CYBRA/logs" "$CYBRA/logs/dumps"

log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

# ── single instance ──
if [ -f "$PIDFILE" ]; then
  OLD=$(cat "$PIDFILE" 2>/dev/null)
  if [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null; then
    log "already running pid=$OLD"; exit 0
  fi
  rm -f "$PIDFILE"
fi
if ! mkdir "$LOCKDIR" 2>/dev/null; then
  if [ -d "$LOCKDIR" ] && [ -n "$(find "$LOCKDIR" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
    rmdir "$LOCKDIR" 2>/dev/null; mkdir "$LOCKDIR" 2>/dev/null || exit 1
  else
    log "locked, exit"; exit 0
  fi
fi
echo $$ > "$PIDFILE"
trap 'rmdir "$LOCKDIR" 2>/dev/null; rm -f "$PIDFILE"' EXIT

# ── intervals ──
TICK="${TICK:-15}"
GOD_CHECK="${GOD_CHECK:-30}"
BG_CHECK="${BG_CHECK:-60}"
GIT_CHECK="${GIT_CHECK:-120}"
HEAL_CHECK="${HEAL_CHECK:-90}"
SELF_CHECK="${SELF_CHECK:-120}"
SELF_MEM_MB="${SELF_MEM_MB:-55}"

# ── auto-setup (перший запуск) ──
setup_once(){
  log "═══ AUTOWATCH SETUP ═══"
  command -v termux-wake-lock >/dev/null && termux-wake-lock 2>/dev/null && log "wake-lock ok"
  for f in bin/cybra_bg_dump.sh bin/cybra_bg_dump_ctl.sh bin/cybra_autogit.sh \
           bin/cybra_dump.sh bin/cybra_dump_components.sh bin/cybra_autorestore.sh \
           bin/wrappers/run_autogit.sh; do
    [ -x "$f" ] || log "⚠ missing: $f"
  done
  touch "$CYBRA/.cache/autowatch.setup.ok"
  log "setup done"
}
[ ! -f "$CYBRA/.cache/autowatch.setup.ok" ] && setup_once

log "═══ AUTOWATCH START ═══ pid=$$ tick=${TICK}s"

# ── helpers ──
god_count(){ pgrep -f "PM2.*God Daemon" 2>/dev/null | wc -l; }
bg_dump_alive(){ [ -f "$CYBRA/.cache/bg_dump.pid" ] && kill -0 "$(cat "$CYBRA/.cache/bg_dump.pid" 2>/dev/null)" 2>/dev/null; }

ensure_god(){
  local n; n=$(god_count)
  if [ "$n" -eq 0 ]; then
    log "god DEAD → resurrect"
    pm2 resurrect >> "$LOG" 2>&1
    sleep 3
    pm2 save --force >> "$LOG" 2>&1
    log "resurrect done online=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length' 2>/dev/null || echo '?')"
  elif [ "$n" -gt 1 ]; then
    log "$n gods → kill extras"
    pgrep -f "PM2.*God Daemon" | tail -n +2 | xargs -r kill -9
  fi
}

ensure_bg_dump(){
  if ! bg_dump_alive; then
    log "bg_dump DEAD → start"
    [ -x "$CYBRA/bin/cybra_bg_dump_ctl.sh" ] && "$CYBRA/bin/cybra_bg_dump_ctl.sh" start >> "$LOG" 2>&1
  fi
}

ensure_autogit(){
  # autogit у pm2
  if god_count >/dev/null && ! pm2 describe cybra-autogit >/dev/null 2>&1; then
    if [ -x "$CYBRA/bin/wrappers/run_autogit.sh" ]; then
      log "autogit missing in pm2 → start"
      pm2 start "$CYBRA/bin/wrappers/run_autogit.sh" --name cybra-autogit --interpreter bash --max-memory-restart 65M >> "$LOG" 2>&1
      pm2 save --force >> "$LOG" 2>&1
    fi
  fi

  # git doctor (раз на ~30 хв): тільки якщо є ознаки проблеми
  local gd_stamp="$CYBRA/.cache/gitdoctor.stamp"
  local now_s; now_s=$(date +%s)
  local last_s=0
  [ -f "$gd_stamp" ] && last_s=$(cat "$gd_stamp" 2>/dev/null || echo 0)
  if [ $((now_s - last_s)) -ge 1800 ]; then
    # тільки перевірка без --fix
    if ! "$CYBRA/bin/cybra_git_doctor.sh" >/dev/null 2>&1; then
      log "git doctor: warnings — running --fix"
      "$CYBRA/bin/cybra_git_doctor.sh" --fix >> "$LOG" 2>&1
    fi
    echo "$now_s" > "$gd_stamp"
  fi
}

autoheal(){
  pm2 jlist 2>/dev/null > "$CYBRA/.cache/pm2.json" || return
  local errs; errs=$(jq -r '[.[]|select(.pm2_env.status=="errored")|.name]|.[]' "$CYBRA/.cache/pm2.json" 2>/dev/null)
  [ -z "$errs" ] && return
  touch "$QUAR"
  local n=0
  for name in $errs; do
    grep -qxF "$name" "$QUAR" && continue
    log "autoheal: restart $name"
    pm2 restart "$name" --max-memory-restart 65M >> "$LOG" 2>&1
    n=$((n+1))
  done
  [ "$n" -gt 0 ] && log "autoheal: restarted $n process(es)"
}

self_check(){
  local kb; kb=$(awk '/VmRSS/{print $2}' /proc/$$/status 2>/dev/null || echo 0)
  local mb=$((kb / 1024))
  if [ "$mb" -gt "$SELF_MEM_MB" ]; then
    log "self: mem=${mb}MB > ${SELF_MEM_MB}MB → re-exec"
    exec "$0" "$@"
  fi
}

rotate_log(){
  [ -f "$LOG" ] || return
  local sz; sz=$(stat -c%s "$LOG" 2>/dev/null || echo 0)
  if [ "$sz" -gt 5242880 ]; then
    tail -c 524288 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    log "log rotated"
  fi
}

# ── main loop ──
LAST_GOD=0; LAST_BG=0; LAST_GIT=0; LAST_HEAL=0; LAST_SELF=0
while true; do
  NOW=$(date +%s)
  [ $((NOW - LAST_GOD))  -ge "$GOD_CHECK"  ] && { ensure_god;     LAST_GOD=$NOW;  }
  [ $((NOW - LAST_BG))   -ge "$BG_CHECK"   ] && { ensure_bg_dump; LAST_BG=$NOW;   }
  [ $((NOW - LAST_GIT))  -ge "$GIT_CHECK"  ] && { ensure_autogit; LAST_GIT=$NOW;  }
  [ $((NOW - LAST_HEAL)) -ge "$HEAL_CHECK" ] && { autoheal;       LAST_HEAL=$NOW; }
  [ $((NOW - LAST_SELF)) -ge "$SELF_CHECK" ] && { self_check;     LAST_SELF=$NOW; }
  rotate_log
  sleep "$TICK"
done
