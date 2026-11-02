#!/data/data/com.termux/files/usr/bin/bash
# cybra_stage.sh — визначає стейдж CYBRA. 0=DEAD..5=GOLDEN
set -u
CYBRA="$HOME/CYBRA"
OUT="$CYBRA/state/stage.json"
mkdir -p "$(dirname "$OUT")"

# ── зібрати факти ──
GODS=$(pgrep -f "PM2.*God Daemon" 2>/dev/null | wc -l)
pm2 jlist > "$CYBRA/.cache/pm2.json" 2>/dev/null || echo '[]' > "$CYBRA/.cache/pm2.json"
TOT=$(jq 'length' "$CYBRA/.cache/pm2.json")
ON=$(jq '[.[]|select(.pm2_env.status=="online")]|length' "$CYBRA/.cache/pm2.json")
ERR=$(jq '[.[]|select(.pm2_env.status=="errored")]|length' "$CYBRA/.cache/pm2.json")
NO65=$(jq '[.[]|select(.pm2_env.status=="online" and ((.pm2_env.max_memory_restart|tostring) as $m | ($m!="65M" and $m!="68157440" and $m!="null")))]|length' "$CYBRA/.cache/pm2.json")
RUNAWAY=$(jq '[.[]|select(.name!="redis" and (.pm2_env.restart_time//0)>200)]|length' "$CYBRA/.cache/pm2.json")
QN=$(ls "$CYBRA/queue/parliament/" 2>/dev/null | wc -l)
RAMFREE=$(free -m | awk '/Mem:/{print int($NF/$2*100)}')
DISK=$(df -Pk "$CYBRA" 2>/dev/null | awk 'NR==2{print int($4/1024)}')
REDIS=$(redis-cli ping 2>/dev/null || echo "NO")
API=$(curl -sf --max-time 3 http://127.0.0.1:8000/health -o /dev/null && echo ok || \
      curl -sf --max-time 3 http://127.0.0.1:8000/docs -o /dev/null && echo ok || echo fail)

# ── 10 гейтів ──
G=()
g(){ G+=("$1:$2"); }
g god_singleton   $([ "$GODS" -eq 1 ] && echo pass || echo fail)
g no_errored      $([ "$ERR" -eq 0 ] && echo pass || echo fail)
g min_online      $([ "$ON" -ge 15 ] && echo pass || echo fail)
g all_65M         $([ "$NO65" -eq 0 ] && echo pass || echo fail)
g redis_pong      $([ "$REDIS" = "PONG" ] && echo pass || echo fail)
g api_health      $([ "$API" = "ok" ] && echo pass || echo fail)
g queue_sane      $([ "$QN" -lt 500 ] && echo pass || echo fail)
g ram_ok          $([ "$RAMFREE" -gt 12 ] && echo pass || echo fail)
g no_runaway      $([ "$RUNAWAY" -eq 0 ] && echo pass || echo fail)
g disk_ok         $([ "${DISK:-0}" -gt 500 ] && echo pass || echo fail)

PASS=$(printf '%s\n' "${G[@]}" | grep -c ':pass$')
FAIL=$((10-PASS))

# ── стейдж ──
if   [ "$GODS" -eq 0 ];                              then STAGE=0; NAME="DEAD"
elif [ "$ON" -eq 0 ];                                then STAGE=1; NAME="BOOT"
elif [ "$ERR" -gt 3 ] || [ "$REDIS" != "PONG" ] || [ "$API" = "fail" ]; then STAGE=2; NAME="DEGRADED"
elif [ "$FAIL" -gt 0 ];                              then STAGE=3; NAME="STABLE"
elif [ "$ON" -lt "$TOT" ];                           then STAGE=4; NAME="ONLINE"
else                                                      STAGE=5; NAME="GOLDEN"
fi

# ── JSON ──
CHECKS=$(printf '"%s",' "${G[@]}" | sed 's/:/": "/g;s/,$//')
{
  echo "{"
  echo "  \"ts\": $(date +%s),"
  echo "  \"stage\": $STAGE,"
  echo "  \"name\": \"$NAME\","
  echo "  \"online\": \"$ON/$TOT\","
  echo "  \"errored\": $ERR,"
  echo "  \"gates_pass\": \"$PASS/10\","
  echo "  \"facts\": {"
  echo "    \"gods\": $GODS, \"redis\": \"$REDIS\", \"api\": \"$API\","
  echo "    \"queue\": $QN, \"ram_free_pct\": $RAMFREE, \"disk_mb\": ${DISK:-0},"
  echo "    \"no_65m\": $NO65, \"runaway\": $RUNAWAY"
  echo "  },"
  echo "  \"gates\": { $CHECKS }"
  echo "}"
} > "$OUT"

# ── людині ──
BAR=$(printf '█%.0s' $(seq 1 $((STAGE*4))) 2>/dev/null)
BAR=$(printf '%-20s' "$BAR" | tr ' ' '·')
echo ""
echo "╔══════════════════════════════════════════╗"
printf "║  STAGE %s/5  %-28s║\n" "$STAGE" "$NAME"
printf "║  %s  ║\n" "$BAR"
printf "║  online %-5s  errored %-3s  gates %-5s ║\n" "$ON/$TOT" "$ERR" "$PASS/10"
echo "╚══════════════════════════════════════════╝"
echo ""
for x in "${G[@]}"; do
  k="${x%:*}"; v="${x##*:}"
  [ "$v" = "pass" ] && echo "  ✅ $k" || echo "  ❌ $k"
done
echo ""
echo "  → $OUT"
echo ""
[ "$STAGE" -eq 5 ] && exit 0 || exit 1
