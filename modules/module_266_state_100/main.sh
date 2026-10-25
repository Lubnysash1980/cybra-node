#!/data/data/com.termux/files/usr/bin/bash
# module_266: state_100 (state) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-check}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="state_100"
MODULE_CAT="state"

case "$ACTION" in
  check)
    echo "════ ${MODULE_LABEL}: 100% state gate ════"
    SCORE=0; MAX=0
    chk() { MAX=$((MAX+1)); if eval "$2" >/dev/null 2>&1; then SCORE=$((SCORE+1)); echo "  ✅ $1"; else echo "  ❌ $1"; fi; }
    chk "redis PONG"         "redis-cli ping | grep -q PONG"
    chk "parliament online"  "pm2 jlist | python3 -c 'import sys,json;d=json.load(sys.stdin);sys.exit(0 if any(p[\"name\"]==\"parliament\" and p[\"pm2_env\"][\"status\"]==\"online\" for p in d) else 1)'"
    chk "menu-worker online" "pm2 jlist | python3 -c 'import sys,json;d=json.load(sys.stdin);sys.exit(0 if any(p[\"name\"]==\"menu-worker\" and p[\"pm2_env\"][\"status\"]==\"online\" for p in d) else 1)'"
    chk "taxi-events online" "pm2 jlist | python3 -c 'import sys,json;d=json.load(sys.stdin);sys.exit(0 if any(p[\"name\"]==\"taxi-events\" and p[\"pm2_env\"][\"status\"]==\"online\" for p in d) else 1)'"
    chk "config token"       "[ -f \"$CYBRA/state/taxi_premium_config.json\" ]"
    chk "i18n en+uk"         "[ -f \"$CYBRA/state/taxi/i18n/en.json\" ] && [ -f \"$CYBRA/state/taxi/i18n/uk.json\" ]"
    chk "modules 240-259"    "[ $(ls -d $CYBRA/modules/module_2[45][0-9]_* 2>/dev/null | wc -l) -ge 20 ]"
    chk "modules 260-279"    "[ $(ls -d $CYBRA/modules/module_2[67][0-9]_* 2>/dev/null | wc -l) -ge 15 ]"
    chk "location fallback"  "[ -x \"$CYBRA/modules/module_265_location_fallback/main.sh\" ]"
    chk "peer camera"        "[ -x \"$CYBRA/modules/module_260_peer_camera/main.sh\" ]"
    PCT=$((SCORE * 100 / MAX))
    echo ""
    echo "  ─── SCORE: $SCORE/$MAX ($PCT%) ───"
    redis-cli hset cybra:taxi:state "$(date +%s)" "score=$SCORE,max=$MAX,pct=$PCT" >/dev/null
    redis-cli set cybra:taxi:state:current "$PCT" >/dev/null
    if [ "$PCT" -eq 100 ]; then
      echo "  🎉 100% READY"
      redis-cli set cybra:taxi:state:ready "1" >/dev/null
      exit 0
    fi
    exit 1
    ;;
  gate)
    READY=$(redis-cli get cybra:taxi:state:ready 2>/dev/null || echo 0)
    PCT=$(redis-cli get cybra:taxi:state:current 2>/dev/null || echo 0)
    if [ "$READY" = "1" ]; then echo "✅ ride allowed ($PCT%)"; exit 0; fi
    echo "❌ ride blocked ($PCT% < 100%)"
    exit 1
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 check | gate"
    ;;
esac
