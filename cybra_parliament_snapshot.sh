#!/data/data/com.termux/files/usr/bin/bash
# PARLIAMENT SNAPSHOT — повний знімок стану Кіберпарламенту
# usage: ./cybra_parliament_snapshot.sh [name]
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
NAME="${1:-auto}"
STAMP="$(date -u +%Y%m%d_%H%M%S)"
DIR="$CYBRA/snapshots/parliament_${NAME}_${STAMP}"
mkdir -p "$DIR"/{redis,pm2,state,scripts,logs}
log(){ echo "[$(date -u +%FT%TZ)] $*" | tee -a "$DIR/snapshot.log"; }

log "═══ PARLIAMENT SNAPSHOT: $NAME ═══"
log "target: $DIR"

# ─── 1. Redis ───
log "→ redis snapshot"
redis-cli save >/dev/null 2>&1
for f in /data/data/com.termux/files/usr/var/lib/redis/dump.rdb \
         ~/.redis/dump.rdb \
         /data/data/com.termux/files/home/.redis/dump.rdb; do
  [ -f "$f" ] && { cp "$f" "$DIR/redis/dump.rdb" 2>/dev/null; break; }
done

# ключові простори
for key in cybra:parliament:queue cybra:parliament:results cybra:parliament:failed \
           cybra:ai_until_done:moved_hashes cybra:owner:directives \
           cybra:complexity:stats cybra:level cybra:progress:ai_until_done; do
  safe=$(echo "$key" | tr ':' '_')
  redis-cli type "$key" 2>/dev/null | grep -qE '^(list|hash|set|zset|string)$' && \
    redis-cli --no-raw dump "$key" 2>/dev/null | head -c 100000 > "$DIR/redis/${safe}.dump" 2>/dev/null
  case $(redis-cli type "$key" 2>/dev/null) in
    list)   redis-cli lrange "$key" 0 -1 > "$DIR/redis/${safe}.txt" 2>/dev/null ;;
    hash)   redis-cli hgetall "$key"    > "$DIR/redis/${safe}.txt" 2>/dev/null ;;
    string) redis-cli get "$key"        > "$DIR/redis/${safe}.txt" 2>/dev/null ;;
    set)    redis-cli smembers "$key"   > "$DIR/redis/${safe}.txt" 2>/dev/null ;;
    zset)   redis-cli zrange "$key" 0 -1 WITHSCORES > "$DIR/redis/${safe}.txt" 2>/dev/null ;;
  esac
done

# усі ключі cybra:*
redis-cli --scan --pattern 'cybra:*' 2>/dev/null | sort > "$DIR/redis/all_keys.txt"
log "  keys: $(wc -l < "$DIR/redis/all_keys.txt")"

# ─── 2. PM2 ───
log "→ pm2 snapshot"
pm2 list > "$DIR/pm2/list.txt" 2>&1
pm2 jlist > "$DIR/pm2/jlist.json" 2>&1
pm2 prettylist > "$DIR/pm2/prettylist.txt" 2>&1
pm2 save >/dev/null 2>&1
[ -f ~/.pm2/dump.pm2 ] && cp ~/.pm2/dump.pm2 "$DIR/pm2/dump.pm2"
# логи кожного процесу
for p in $(pm2 jlist 2>/dev/null | python3 -c "import sys,json;[print(p['name']) for p in json.load(sys.stdin)]" 2>/dev/null); do
  pm2 logs "$p" --lines 100 --nostream > "$DIR/logs/${p}.log" 2>&1 || true
done

# ─── 3. State файли ───
log "→ state snapshot"
cp -r state "$DIR/state/" 2>/dev/null
cp feeds/ai_until_done_report.json "$DIR/state/" 2>/dev/null
cp posts/ai_until_done_report.md    "$DIR/state/" 2>/dev/null
[ -d evo ] && find evo -maxdepth 2 -type f -name '*.json' 2>/dev/null | head -50 | tar -czf "$DIR/state/evo_proofs.tgz" -T - 2>/dev/null

# ─── 4. Скрипти ───
log "→ scripts snapshot"
for s in cybra_complexity_v3.sh cybra_level_tracker.sh cybra_state.sh \
         cybra_ai_until_done.sh parliament_executor_v6.py \
         cybra_ai_safe.sh ecosystem.config.js; do
  [ -f "$s" ] && cp "$s" "$DIR/scripts/"
done

# ─── 5. Метадані ───
log "→ metadata"
cat > "$DIR/metadata.json" <<META
{
  "snapshot_name": "$NAME",
  "timestamp_utc": "$(date -u +%FT%TZ)",
  "timestamp_epoch": $(date +%s),
  "level": $(cat state/cybra.level 2>/dev/null || echo 0),
  "redis_pong": "$(redis-cli ping 2>/dev/null || echo DOWN)",
  "queue": $(redis-cli llen cybra:parliament:queue 2>/dev/null || echo 0),
  "results": $(redis-cli llen cybra:parliament:results 2>/dev/null || echo 0),
  "failed": $(redis-cli llen cybra:parliament:failed 2>/dev/null || echo 0),
  "audit": $(redis-cli llen cybra:ai_until_done:audit 2>/dev/null || echo 0),
  "executors_running": $(ps aux | grep -c '[p]arliament_executor'),
  "ram_pct": $(free -m | awk '/Mem:/{printf "%d",$3/$2*100}'),
  "modules_count": $(ls modules 2>/dev/null | wc -l),
  "pm2_processes": $(pm2 jlist 2>/dev/null | python3 -c "import sys,json;print(len(json.load(sys.stdin)))" 2>/dev/null || echo 0)
}
META

# ─── 6. Git commit в репо ───
if [ -d .git ]; then
  log "→ git commit"
  git add -A 2>/dev/null
  git -c user.email="snapshot@cybra.local" -c user.name="cybra-snapshot" \
      commit -m "snapshot: parliament $NAME @ $STAMP" 2>&1 | tail -2 >> "$DIR/snapshot.log"
  git rev-parse HEAD > "$DIR/git_commit.txt" 2>/dev/null
fi

# ─── 7. Стиснення ───
log "→ compress"
TARBALL="$CYBRA/snapshots/parliament_${NAME}_${STAMP}.tar.gz"
tar -czf "$TARBALL" -C "$CYBRA/snapshots" "parliament_${NAME}_${STAMP}" 2>/dev/null
SIZE=$(du -h "$TARBALL" | awk '{print $1}')

# ─── 8. Покажчик ───
echo "$TARBALL" >> "$CYBRA/snapshots/INDEX.txt"

log "✅ snapshot ready: $TARBALL ($SIZE)"
echo
echo "════════════════════════════════════════════"
echo "📸 SNAPSHOT: $NAME"
echo "📁 $TARBALL ($SIZE)"
echo "📊 $(cat "$DIR/metadata.json" | python3 -m json.tool 2>/dev/null | head -20)"
echo "════════════════════════════════════════════"
