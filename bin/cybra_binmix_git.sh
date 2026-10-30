#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail
REPO="${BINMIX_REPO:-$HOME/cybra-node}"
CYBRA="${CYBRA:-$HOME/CYBRA}"
AUD="$CYBRA/audit"; LOG="$CYBRA/logs/binmix-git.log"
mkdir -p "$(dirname "$LOG")" "$AUD"
lg(){ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }

ACTION="${1:-mix}"
case "$ACTION" in
  search)
    echo "═══ binmix-git search: $REPO ═══"
    N=$(find "$REPO/modules" -name 'main.sh' -o -name 'cybra_mod_*.sh' 2>/dev/null | wc -l)
    echo "  всього: $N"
    ;;
  mix)
    echo "═══ binmix-git mix (by relative path) ═══"
    cd "$REPO"
    MIXED=0; SKIP=0; MISS=0
    while IFS= read -r row; do
      N=$(echo "$row" | jq -r .n)
      NAME=$(echo "$row" | jq -r .name)
      FILE=$(echo "$row" | jq -r '.file // empty')
      [ -z "$FILE" ] && continue

      # точний шлях у git
      GITFILE="$REPO/$FILE"
      if [ ! -f "$GITFILE" ]; then
        # альтернатива — шукаємо по модулю
        MOD=$(echo "$FILE" | grep -oE 'module_[0-9]+_[a-z_0-9]+' | head -1)
        if [ -n "$MOD" ]; then
          GITFILE=$(find "$REPO/modules" -type f -path "*${MOD}/main.sh" 2>/dev/null | head -1)
        fi
      fi
      if [ -z "$GITFILE" ] || [ ! -f "$GITFILE" ]; then
        MISS=$((MISS+1))
        continue
      fi

      LOCAL="$CYBRA/$FILE"
      if [ -f "$LOCAL" ]; then
        if cmp -s "$GITFILE" "$LOCAL"; then
          SKIP=$((SKIP+1)); continue
        fi
      fi
      mkdir -p "$(dirname "$LOCAL")"
      cp "$GITFILE" "$LOCAL"
      chmod +x "$LOCAL"
      MIXED=$((MIXED+1))
      lg "MIX [$N] $NAME ← $FILE"
    done < <(jq -c '.[]' "$AUD/base-map.json")

    echo "  mixed: $MIXED"
    echo "  skip:  $SKIP (не змінилось)"
    echo "  miss:  $MISS (нема в git)"
    lg "mix done: mixed=$MIXED skip=$SKIP miss=$MISS"
    ;;
  status)
    echo "═══ binmix-git status ═══"
    cd "$REPO"
    echo "  branch: $(git branch --show-current)"
    echo "  commits: $(git rev-list --count HEAD)"
    echo "  base-map: $(jq 'length' "$AUD/base-map.json" 2>/dev/null || echo 0)"
    echo "  files-in-git: $(git ls-files | wc -l)"
    ;;
esac
