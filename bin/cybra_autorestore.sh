#!/data/data/com.termux/files/usr/bin/bash
# cybra_autorestore.sh — якщо поточний стан гірший за кращий дамп → restore.
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
LOG="$CYBRA/logs/autorestore.log"; mkdir -p "$(dirname "$LOG")"
log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }

# ── 1. Поточний score ──
pm2 jlist > "$CYBRA/.cache/pm2.json" 2>/dev/null || echo '[]' > "$CYBRA/.cache/pm2.json"
CUR_TOT=$(jq 'length' "$CYBRA/.cache/pm2.json")
CUR_ON=$(jq '[.[]|select(.pm2_env.status=="online")]|length' "$CYBRA/.cache/pm2.json")
CUR_ERR=$(jq '[.[]|select(.pm2_env.status=="errored")]|length' "$CYBRA/.cache/pm2.json")
CUR_STG=$(jq -r '.stage // 0' "$CYBRA/state/stage.json" 2>/dev/null || echo 0)
CUR_PCT=$(jq -r '.overall.percent // 0' "$CYBRA/state/manifest.json" 2>/dev/null || echo 0)
CUR_SCORE=$(( CUR_STG*100 + ${CUR_PCT%.*} - CUR_ERR*50 ))

# ── 2. Знайти найкращий дамп серед 3 ──
BEST=""
BEST_SCORE=-999999
for mf in "$CYBRA"/dumps/dump_*/MANIFEST.json; do
  [ -f "$mf" ] || continue
  sc=$(jq -r '.score // -999999' "$mf")
  if [ "$sc" -gt "$BEST_SCORE" ]; then
    BEST_SCORE=$sc
    BEST=$(dirname "$mf")
  fi
done

if [ -z "$BEST" ]; then
  log "no dumps — skip"
  exit 0
fi

log "current score=$CUR_SCORE (stage=$CUR_STG, ${CUR_ON}/${CUR_TOT}online, ${CUR_ERR}err, ${CUR_PCT}%)"
log "best dump    $BEST score=$BEST_SCORE"

# ── 3. Умова відновлення ──
# Відновлюємо тільки якщо:
#   - поточний score < 200 (щось зламано), АБО
#   - best_score - cur_score > 150 (dump значно кращий), АБО
#   - errored >= 3 (багато зламаних)
NEED=0
[ "$CUR_SCORE" -lt 200 ] && NEED=1
[ $(( BEST_SCORE - CUR_SCORE )) -gt 150 ] && NEED=1
[ "$CUR_ERR" -ge 3 ] && NEED=1

if [ "$NEED" -eq 0 ]; then
  log "current state OK — no restore needed"
  exit 0
fi

log "⚠ restore needed → $BEST"

# ── 4. Restore ──
pgrep -f "PM2.*God Daemon" | xargs -r kill -9
sleep 2
cp "$BEST/pm2.dump" ~/.pm2/dump.pm2 2>/dev/null
pm2 resurrect >>"$LOG" 2>&1
sleep 3
pm2 save --force >>"$LOG" 2>&1
cp "$BEST/state/"*.json "$CYBRA/state/" 2>/dev/null

# ── 5. Звіт ──
NEW_ON=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length')
NEW_TOT=$(pm2 jlist 2>/dev/null | jq 'length')
log "✓ restored: ${NEW_ON}/${NEW_TOT} online"

# ── 6. Записати факт відновлення ──
echo "{\"ts\": $(date +%s), \"from\": \"$BEST\", \"score_before\": $CUR_SCORE, \"score_dump\": $BEST_SCORE, \"online_after\": \"$NEW_ON/$NEW_TOT\"}" >> "$CYBRA/state/restores.jsonl"
