#!/data/data/com.termux/files/usr/bin/bash
# module_265: location_fallback (loc) — ultra
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-show}"; shift $(( $# > 0 ? 1 : 0 ))

case "$ACTION" in
  fix)
    SRC=""; LAT=""; LON=""
    # 1. GPS
    if command -v termux-location >/dev/null 2>&1; then
      GPS=$(timeout 5 termux-location -p gps 2>/dev/null || true)
      if [ -n "$GPS" ]; then
        LAT=$(printf '%s' "$GPS" | python3 -c "import sys,json;print(json.load(sys.stdin).get('latitude',''))" 2>/dev/null || true)
        LON=$(printf '%s' "$GPS" | python3 -c "import sys,json;print(json.load(sys.stdin).get('longitude',''))" 2>/dev/null || true)
        [ -n "$LAT" ] && SRC="gps"
      fi
    fi
    # 2. Network
    if [ -z "$SRC" ] && command -v termux-location >/dev/null 2>&1; then
      NET=$(timeout 5 termux-location -p network 2>/dev/null || true)
      if [ -n "$NET" ]; then
        LAT=$(printf '%s' "$NET" | python3 -c "import sys,json;print(json.load(sys.stdin).get('latitude',''))" 2>/dev/null || true)
        LON=$(printf '%s' "$NET" | python3 -c "import sys,json;print(json.load(sys.stdin).get('longitude',''))" 2>/dev/null || true)
        [ -n "$LAT" ] && SRC="network"
      fi
    fi
    # 3. Cell
    if [ -z "$SRC" ] && command -v termux-telephony-cellinfo >/dev/null 2>&1; then
      CELL=$(timeout 5 termux-telephony-cellinfo 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    if isinstance(d,list): d=d[0]
    print(f\"{d.get('mcc','?')},{d.get('mnc','?')},{d.get('cid','?')}\")
except: pass
" 2>/dev/null || true)
      if [ -n "$CELL" ]; then
        LAT="$CELL"; LON="cell"; SRC="cell"
      fi
    fi
    # 4. Last known
    if [ -z "$SRC" ]; then
      LAST=$(redis-cli hget cybra:taxi:location:last any 2>/dev/null || true)
      if [ -n "$LAST" ]; then
        LAT=$(printf '%s' "$LAST" | cut -d'|' -f1)
        LON=$(printf '%s' "$LAST" | cut -d'|' -f2)
        SRC="last_known"
      fi
    fi
    if [ -z "$SRC" ]; then
      echo "❌ no location (no GPS, no cell, no last known)"
      echo "   → use 'mark <lat> <lon>' to set manually"
      exit 1
    fi
    redis-cli hset cybra:taxi:location:last "any" "$LAT|$LON|$SRC|$(date -u +%FT%TZ)" >/dev/null
    echo "📍 fix: $LAT,$LON  (source: $SRC)"
    ;;
  mark)
    LAT="${1:-}"; LON="${2:-}"
    if [ -z "$LAT" ] || [ -z "$LON" ]; then
      echo "usage: $0 mark <lat> <lon>"
      exit 1
    fi
    redis-cli hset cybra:taxi:location:last "any" "$LAT|$LON|manual|$(date -u +%FT%TZ)" >/dev/null
    echo "📍 manual: $LAT,$LON"
    ;;
  show|*)
    echo "════ location_fallback ════"
    LAST=$(redis-cli hget cybra:taxi:location:last any 2>/dev/null || true)
    if [ -n "$LAST" ]; then
      printf '  %s\n' "$LAST" | awk -F'|' '{print "  lat="$1"  lon="$2"  src="$3"  at="$4}'
    else
      echo "  (no location yet)"
    fi
    echo "  hint: $0 fix | mark <lat> <lon>"
    ;;
esac
