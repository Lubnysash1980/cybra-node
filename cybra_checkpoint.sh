#!/data/data/com.termux/files/usr/bin/bash
# CYBRA 100% POINT-IN-TIME CHECKPOINT
# save | verify | rollback | list
set -u
cd "$HOME/CYBRA" || exit 1
CMD="${1:-verify}"

verify_silent() {
  local fail=0
  # 1. всі pm2 online (крім явно stopped-за-дизайном)
  local err
  err=$(pm2 jlist 2>/dev/null | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{try{JSON.parse(d).forEach(p=>{if(p.pm2_env.status==="errored")console.log("ERR:"+p.name)})}catch(e){}})')
  [ -n "$err" ] && { echo "  ✗ errored: $err"; fail=1; }
  # 2. RAM < 90%
  local pct
  pct=$(free -m | awk 'NR==2{print int($3*100/$2)}')
  [ "$pct" -ge 90 ] && { echo "  ✗ RAM ${pct}% ≥ 90%"; fail=1; }
  # 3. redis живий
  command -v redis-cli >/dev/null && [ "$(redis-cli ping 2>/dev/null)" != "PONG" ] && { echo "  ✗ redis не відповідає"; fail=1; }
  # 4. ключові процеси online
  for n in redis menu-worker taxi-events cybra-api; do
    pm2 jlist 2>/dev/null | grep -q "\"name\":\"$n\"" || { echo "  ✗ нема $n в pm2"; fail=1; }
  done
  return $fail
}

case "$CMD" in
  verify)
    echo "=== VERIFY 100% ==="
    if verify_silent; then echo "  ✅ 100% СТАН"; exit 0
    else echo "  ❌ НЕ 100%"; exit 1; fi
    ;;
  save)
    echo "=== SAVE 100% POINT ==="
    if ! verify_silent; then echo "  ❌ не 100%, збереження відхилено"; exit 1; fi
    TS=$(date +%Y%m%d_%H%M%S)
    TAG="pct100-$TS"
    pm2 save >/dev/null 2>&1
    cp ~/.pm2/dump.pm2 "runtime/snapshots/dump.pm2.$TS" 2>/dev/null
    git add -A >/dev/null 2>&1
    git -c user.email=auto@cybra -c user.name=cybra commit -m "pct100 checkpoint $TS" >/dev/null 2>&1 || true
    git tag -f "$TAG" >/dev/null 2>&1
    echo "  ✅ точка збережена: $TAG"
    echo "  git: $(git log -1 --oneline)"
    echo "  dump: runtime/snapshots/dump.pm2.$TS"
    ;;
  rollback)
    LAST=$(git tag -l 'pct100-*' | sort | tail -1)
    [ -z "$LAST" ] && { echo "❌ нема збережених точок"; exit 1; }
    echo "=== ROLLBACK → $LAST ==="
    git reset --hard "$LAST" >/dev/null 2>&1
    DUMP=$(ls -1t runtime/snapshots/dump.pm2.* 2>/dev/null | head -1)
    [ -n "$DUMP" ] && cp "$DUMP" ~/.pm2/dump.pm2 && pm2 resurrect >/dev/null 2>&1
    echo "  ✅ відкат: $(git log -1 --oneline)"
    ;;
  list)
    echo "=== 100% ТОЧКИ ==="
    git tag -l 'pct100-*' | sort | while read t; do
      echo "  $t  $(git log -1 --format='%h %s' "$t")"
    done
    ;;
  *)
    echo "Usage: bash cybra_checkpoint.sh save|verify|rollback|list"
    ;;
esac
