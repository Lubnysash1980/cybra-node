#!/data/data/com.termux/files/usr/bin/bash
# module_242: route_preference (map) — taxi_premium
# generated 2026-10-25T23:07:35Z
set -u
CYBRA="${CYBRA:-$HOME/CYBRA}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${1:-show}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="route_preference"
MODULE_CAT="map"

CONF="$CYBRA/state/taxi_premium_config.json"
case "$ACTION" in
  add|mark)
    ID="${1:-}"; LAT="${2:-0}"; LON="${3:-0}"; NOTE="${4:-order}"
    [ -z "$ID" ] && { echo "usage: $0 add <id> <lat> <lon> [note]"; exit 1; }
    redis-cli hset "cybra:taxi:map:markers" "$ID" "$LAT,$LON,$NOTE,$(date -u +%FT%TZ)" >/dev/null
    echo "📍 marker $ID @ $LAT,$LON ($NOTE)"
    ;;
  zones)
    ID="${1:-}"; LAT="${2:-0}"; LON="${3:-0}"; R="${4:-200}"; REASON="${5:-residential}"
    [ -z "$ID" ] && { echo "usage: $0 zones <id> <lat> <lon> [radius_m] [reason]"; exit 1; }
    redis-cli hset "cybra:taxi:map:zones" "$ID" "$LAT,$LON,$R,$REASON" >/dev/null
    echo "🚫 avoid zone $ID @ $LAT,$LON r=${R}m ($REASON)"
    ;;
  near)
    LAT="${1:-0}"; LON="${2:-0}"; MAX_KM="${3:-5}"
    echo "════ ${MODULE_LABEL} (near) ════"
    echo "  origin: $LAT,$LON  radius: ${MAX_KM}km"
    redis-cli hgetall cybra:taxi:map:markers 2>/dev/null | paste - - | while read k v; do
      echo "    $k → $v"
    done
    ;;
  set)
    KEY="${1:-}"; VAL="${2:-}"
    [ -z "$KEY" ] && { echo "usage: $0 set <pref> <value>"; exit 1; }
    redis-cli hset "cybra:taxi:pref:${MODULE_CAT}" "$KEY" "$VAL" >/dev/null
    echo "✅ ${MODULE_CAT}: $KEY = $VAL"
    ;;
  enable|disable)
    STATE=$([ "$ACTION" = "enable" ] && echo "1" || echo "0")
    redis-cli set "cybra:taxi:pref:${MODULE_CAT}:enabled" "$STATE" >/dev/null
    echo "✅ ${MODULE_CAT} ${ACTION}d"
    ;;
  show)
    echo "════ ${MODULE_LABEL} ════"
    redis-cli hgetall "cybra:taxi:pref:${MODULE_CAT}" 2>/dev/null | paste - -
    echo "  enabled: $(redis-cli get "cybra:taxi:pref:${MODULE_CAT}:enabled" 2>/dev/null || echo 0)"
    ;;
  list|*)
    echo "════ ${MODULE_LABEL} ════"
    echo "  markers: $(redis-cli hlen cybra:taxi:map:markers 2>/dev/null || echo 0)"
    echo "  zones:   $(redis-cli hlen cybra:taxi:map:zones 2>/dev/null || echo 0)"
    echo "  hint: $0 add <id> <lat> <lon> | zones <id> <lat> <lon> <r> <reason> | near <lat> <lon> [km] | set/show"
    ;;
esac
