#!/data/data/com.termux/files/usr/bin/bash
# module_265: location_fallback (loc) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-show}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="location_fallback"
MODULE_CAT="loc"

case "$ACTION" in
  fix)
    # fusion: try gps → cell → last_known → manual
    SRC=""; LAT=""; LON=""
    # 1. GPS via termux-location
    if command -v termux-location >/dev/null 2>&1; then
      GPS=$(timeout 5 termux-location -p gps 2>/dev/null)
      if [ -n "$GPS" ]; then
        LAT=$(echo "$GPS" | python3 -c "import sys,json;print(json.load(sys.stdin).get('latitude',''))" 2>/dev/null)
        LON=$(echo "$GPS" | python3 -c "import sys,json;print(json.load(sys.stdin).get('longitude',''))" 2>/dev/null)
        [ -n "$LAT" ] && SRC="gps"
      fi
    fi
    # 2. Network-based (wifi/cell)
    if [ -z "$SRC" ] && command -v termux-location >/dev/null 2>&1; then
      NET=$(timeout 5 termux-location -p network 2>/dev/null)
      if [ -n "$NET" ]; then
        LAT=$(echo "$NET" | python3 -c "import sys,json;print(json.load(sys.stdin).get('latitude',''))" 2>/dev/null)
        LON=$(echo "$NET" | python3 -c "import sys,json;print(json.load(sys.stdin).get('longitude',''))" 2>/dev/null)
        [ -n "$LAT" ] && SRC="network"
      fi
    fi
    # 3. Cell tower
    if [ -z "$SRC" ] && command -v termux-telephony-cellinfo >/dev/null 2>&1; then
      CELL=$(timeout 5 termux-telephony-cellinfo 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    if isinstance(d,list): d=d[0]
    print(f\"{d.get('mcc','?')},{d.get('mnc','?')},{d.get('cid','?')}")
except: pass
")
      [ -n "$CELL" ] && { LAT="$CELL"; LON="cell"; SRC="cell"; }
    fi
    # 4. Last known
    if [ -z "$SRC" ]; then
      LAST=$(redis-cli hget cybra:taxi:location:last "any" 2>/dev/null)
      if [ -n "$LAST" ]; then
        LAT=$(echo "$LAST" | cut -d'|' -f1); LON=$(echo "$LAST" | cut -d'|' -f2); SRC="last_known"
      fi
    fi
    if [ -z "$SRC" ]; then
      echo "❌ no location (no GPS, no cell, no last known)"
      echo "   → use 'mark' to set manually"
      exit 1
    fi
    redis-cli hset cybra:taxi:location:last "any" "$LAT|$LON|$SRC|$(date -u +%FT%TZ)" >/dev/null
    echo "📍 fix: $LAT,$LON  (source: $SRC)"
    ;;
  mark)
    LAT="${1:-}"; LON="${2:-}"
    [ -z "$LAT" ] || [ -z "$LON" ] && { echo "usage: $0 mark <lat> <lon>"; exit 1; }
    redis-cli hset cybra:taxi:location:last "any" "$LAT|$LON|manual|$(date -u +%FT%TZ)" >/dev/null
    echo "📍 manual: $LAT,$LON"
    ;;
  show|*)
    echo "════ ${MODULE_LABEL} ════"
    redis-cli hget cybra:taxi:location:last "any" 2>/dev/null | awk -F'|' '{
      print "  lat=" $1 "  lon=" $2 "  src=" $3 "  at=" $4
    }'
    echo "  hint: $0 fix | mark <lat> <lon>"
    ;;
esac
