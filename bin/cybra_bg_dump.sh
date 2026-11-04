#!/data/data/com.termux/files/usr/bin/bash
# cybra_bg_dump.sh — фоновий дамп, незалежний від pm2 god.
# Запуск:  setsid nohup bin/cybra_bg_dump.sh >/dev/null 2>&1 &
# Зупинка: kill $(cat ~/CYBRA/.cache/bg_dump.pid)
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
PIDFILE="$CYBRA/.cache/bg_dump.pid"
LOCK="$CYBRA/.cache/bg_dump.lock"
LOG="$CYBRA/logs/bg_dump.log"
mkdir -p "$CYBRA/.cache" "$CYBRA/logs"

# ── single instance ──
if [ -f "$PIDFILE" ]; then
  OLD=$(cat "$PIDFILE" 2>/dev/null)
  if [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null; then
    echo "already running pid=$OLD" | tee -a "$LOG"
    exit 0
  fi
fi
if ! mkdir "$LOCK" 2>/dev/null; then
  if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null
    mkdir "$LOCK" 2>/dev/null || { echo "locked, exit"; exit 0; }
  else
    echo "locked, exit"; exit 0
  fi
fi
echo $$ > "$PIDFILE"
trap 'rmdir "$LOCK" 2>/dev/null; rm -f "$PIDFILE"' EXIT

log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

COMP_INTERVAL="${COMP_INTERVAL:-60}"     # компонентний кожні 60с
GLOBAL_INTERVAL="${GLOBAL_INTERVAL:-900}" # глобальний кожні 15 хв
GOD_CHECK="${GOD_CHECK:-30}"              # перевірка pm2 кожні 30с

log "═══ BG DUMP START ═══ pid=$$ comp=${COMP_INTERVAL}s global=${GLOBAL_INTERVAL}s godcheck=${GOD_CHECK}s"

# ── wake-lock ──
command -v termux-wake-lock >/dev/null && termux-wake-lock 2>/dev/null && log "wake-lock ok"

LAST_COMP=0
LAST_GLOBAL=0
LAST_GOD=0

while true; do
  NOW=$(date +%s)

  # ── 1. pm2 god health + resurrect ──
  if [ $((NOW - LAST_GOD)) -ge "$GOD_CHECK" ]; then
    GODS=$(pgrep -f "PM2.*God Daemon" 2>/dev/null | wc -l)
    if [ "$GODS" -eq 0 ]; then
      log "⚠ pm2 god DEAD → resurrect"
      pm2 resurrect >>"$LOG" 2>&1
      sleep 3
      pm2 save --force >>"$LOG" 2>&1
      log "✓ resurrect done, online=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length' 2>/dev/null || echo '?')"
    elif [ "$GODS" -gt 1 ]; then
      log "⚠ $GODS gods → kill extras"
      pgrep -f "PM2.*God Daemon" | tail -n +2 | xargs -r kill -9
    fi
    LAST_GOD=$NOW
  fi

  # ── 2. component dump ──
  if [ $((NOW - LAST_COMP)) -ge "$COMP_INTERVAL" ]; then
    if pgrep -f "PM2.*God Daemon" >/dev/null; then
      "$CYBRA/bin/cybra_dump_components.sh" >>"$LOG" 2>&1 \
        && log "comp dump ok" \
        || log "comp dump fail"
    else
      log "skip comp dump (no god)"
    fi
    LAST_COMP=$NOW
  fi

  # ── 3. global dump ──
  if [ $((NOW - LAST_GLOBAL)) -ge "$GLOBAL_INTERVAL" ]; then
    if pgrep -f "PM2.*God Daemon" >/dev/null; then
      "$CYBRA/bin/cybra_dump.sh" >>"$LOG" 2>&1 \
        && log "global dump ok" \
        || log "global dump fail"
    else
      log "skip global dump (no god)"
    fi
    LAST_GLOBAL=$NOW
  fi

  # ── 4. rotація власного логу (> 5 MB → обрізати до 512 KB) ──
  if [ -f "$LOG" ] && [ "$(stat -c%s "$LOG" 2>/dev/null || echo 0)" -gt 5242880 ]; then
    tail -c 524288 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    log "log rotated"
  fi

  sleep 10
done
