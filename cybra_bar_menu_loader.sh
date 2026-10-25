#!/data/data/com.termux/files/usr/bin/bash
set -eu
TARGET="${1:-160}"
PENDING="cybra:menu:pending"
MODDIR="$HOME/CYBRA/modules/module_160_base"

redis-cli del "$PENDING" >/dev/null

echo "→ генерую $TARGET пунктів → $PENDING"
for i in $(seq 1 "$TARGET"); do
  printf '{"id":"bar_%03d","n":%d,"title":"Bar item %d","level":%d}' \
    "$i" "$i" "$i" $(( (i % 7) + 1 )) \
    | redis-cli -x rpush "$PENDING" >/dev/null
done

echo "✅ pending: $(redis-cli llen "$PENDING")"
