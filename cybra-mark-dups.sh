#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA" || exit 1

MARKED=0
for m in modules/*_module_*/; do
    [ -d "$m" ] || continue
    name=$(basename "$m")

    # Витягуємо номер: module_200_module_200 → 200
    num=$(echo "$name" | sed -n 's/^module_\([0-9]*\)_module_.*/\1/p')
    [ -z "$num" ] && continue

    # Шукаємо "справжній" модуль з тим самим номером
    real=$(ls -d modules/module_${num}_[a-z]* 2>/dev/null | grep -v "_module_" | head -1)

    if [ -n "$real" ]; then
        real_name=$(basename "$real")
        mf="$m/manifest.json"
        if [ -f "$mf" ]; then
            jq --arg r "$real_name" '. + {duplicate_of: $r, stub: true}' "$mf" > "$mf.tmp" && mv "$mf.tmp" "$mf"
            MARKED=$((MARKED+1))
        fi
    fi
done

echo "✅ Позначено дублів: $MARKED"
