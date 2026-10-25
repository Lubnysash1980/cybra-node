#!/data/data/com.termux/files/usr/bin/bash
# PARLIAMENT RESTORE — відновлення зі снапшоту
# usage: ./cybra_parliament_restore.sh <tarball|latest|list>
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
SNAPS="$CYBRA/snapshots"

case "${1:-latest}" in
  list)
    echo "─── Доступні снапшоти ───"
    ls -1t "$SNAPS"/parliament_*.tar.gz 2>/dev/null | head -20
    exit 0 ;;
  latest|"")
    TARBALL=$(ls -1t "$SNAPS"/parliament_*.tar.gz 2>/dev/null | head -1) ;;
  *)
    TARBALL="$1"
    [ -f "$TARBALL" ] || {
      # шукати за точним ім'ям у snapshots/
      [ -f "$SNAPS/$1" ] && TARBALL="$SNAPS/$1" || {
        # шукати найновіший за префіксом
        TARBALL=$(ls -1t "$SNAPS"/parliament_"$1"_*.tar.gz 2>/dev/null | head -1)
        [ -z "$TARBALL" ] && TARBALL=$(ls -1t "$SNAPS"/*"$1"*.tar.gz 2>/dev/null | head -1)
      }
    } ;;
esac

[ -f "$TARBALL" ] || { echo "❌ не знайдено: $TARBALL"; exit 1; }
echo "🔄 відновлення з: $TARBALL"

WORK=$(mktemp -d)
tar -xzf "$TARBALL" -C "$WORK"
SNAP_DIR=$(find "$WORK" -maxdepth 1 -type d -name 'parliament_*' | head -1)
[ -d "$SNAP_DIR" ] || { echo "❌ пошкоджений архів"; exit 1; }

echo "📊 метадані:"
cat "$SNAP_DIR/metadata.json" 2>/dev/null | python3 -m json.tool | head -20

# 1. redis
if [ -f "$SNAP_DIR/redis/dump.rdb" ]; then
  echo "→ redis restore"
  pm2 stop redis 2>/dev/null
  for f in /data/data/com.termux/files/usr/var/lib/redis/dump.rdb \
           ~/.redis/dump.rdb; do
    [ -d "$(dirname "$f")" ] && { cp "$SNAP_DIR/redis/dump.rdb" "$f" 2>/dev/null; break; }
  done
  pm2 start redis 2>/dev/null || pm2 start redis-server --name redis -- --daemonize no
  sleep 2
fi

# 2. state
[ -d "$SNAP_DIR/state" ] && { echo "→ state restore"; cp -r "$SNAP_DIR/state/"* state/ 2>/dev/null; }

# 2.1 після resurrect — прибрати runtime (не потрібен на Termux)
pm2 delete runtime 2>/dev/null && echo "→ runtime прибрано" || true

# 3. pm2
if [ -f "$SNAP_DIR/pm2/dump.pm2" ]; then
  echo "→ pm2 resurrect"
  cp "$SNAP_DIR/pm2/dump.pm2" ~/.pm2/dump.pm2 2>/dev/null
  pm2 resurrect 2>/dev/null
fi

# 4. ключові списки з тексту — ЗАВЖДИ відновлюємо (не залежить від queue)
if [ -f "$SNAP_DIR/redis/cybra_parliament_results.txt" ]; then
  echo "→ redis: відновлення ключів з текстових дампів"
  for f in "$SNAP_DIR/redis"/cybra_*.txt; do
    [ -s "$f" ] || continue
    key=$(basename "$f" .txt | tr '_' ':')
    case "$key" in
      cybra:parliament:queue|cybra:parliament:results|cybra:parliament:failed)
        redis-cli del "$key" >/dev/null
        while IFS= read -r line; do
          [ -n "$line" ] && printf '%s' "$line" | redis-cli -x rpush "$key" >/dev/null
        done < "$f"
        echo "  $key: $(redis-cli llen "$key")" ;;
      cybra:complexity:stats)
        redis-cli del "$key" >/dev/null
        awk 'NR%2{key=$0;next}{print key" "$0}' "$f" | while read k v; do
          redis-cli hset cybra:complexity:stats "$k" "$v" >/dev/null
        done
        echo "  stats: $(redis-cli hlen cybra:complexity:stats)" ;;
      cybra:level)
        redis-cli set cybra:level "$(head -1 "$f")" >/dev/null
        echo "  level: $(redis-cli get cybra:level)" ;;
    esac
  done
fi

echo "→ перезапуск ключових процесів"
pm2 restart parliament level-tracker 2>/dev/null
pm2 save

echo
echo "✅ RESTORED"
echo "level:    $(cat state/cybra.level 2>/dev/null || echo ?)/7"
echo "queue:    $(redis-cli llen cybra:parliament:queue)"
echo "results:  $(redis-cli llen cybra:parliament:results)"
echo "redis:    $(redis-cli ping 2>/dev/null || echo DOWN)"
echo
echo "📊 верифікація проти снапшоту:"
SNAP_RESULTS=$(python3 -c "import json;print(json.load(open('$SNAP_DIR/metadata.json'))['results'])" 2>/dev/null || echo 0)
NOW_RESULTS=$(redis-cli llen cybra:parliament:results 2>/dev/null || echo 0)
if [ "$SNAP_RESULTS" = "$NOW_RESULTS" ]; then
  echo "  ✅ results: $NOW_RESULTS (як у снапшоті)"
else
  echo "  ⚠️  results: снапшот $SNAP_RESULTS, зараз $NOW_RESULTS"
fi

rm -rf "$WORK"
