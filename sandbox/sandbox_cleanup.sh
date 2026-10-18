#!/data/data/com.termux/files/usr/bin/bash
set -uo pipefail

SB="$HOME/CYBRA/sandbox"
LIMIT_MB=65
LIMIT_BYTES=$((LIMIT_MB * 1024 * 1024))

echo "═══ Sandbox Cleanup ═══"

# 1. Видаляємо trash
rm -rf "$SB/trash"/* 2>/dev/null || true
echo "  [✓] trash очищено"

# 2. Видаляємо старі логи (старші 7 днів)
find "$SB/logs" -type f -mtime +7 -delete 2>/dev/null || true
echo "  [✓] старі логи видалено"

# 3. Видаляємо старі keep (старші 30 днів)
find "$SB/keep" -type f -mtime +30 -delete 2>/dev/null || true
echo "  [✓] старі keep видалено"

# 4. Перевіряємо розмір
SIZE="$(du -sb "$SB" 2>/dev/null | awk '{print $1}' || echo 0)"
echo ""
echo "  Розмір: $((SIZE/1024/1024)) МБ / ${LIMIT_MB} МБ"

if [ "$SIZE" -ge "$LIMIT_BYTES" ]; then
    echo "  ⚠ Переповнено! Видаляємо найстаріші файли..."
    find "$SB/bin" "$SB/keep" -type f -printf '%T@ %p\n' 2>/dev/null | \
        sort -n | \
        head -10 | \
        awk '{print $2}' | \
        while read -r f; do
            rm -f "$f" 2>/dev/null || true
        done
fi

SIZE="$(du -sb "$SB" 2>/dev/null | awk '{print $1}' || echo 0)"
echo "  Після очищення: $((SIZE/1024/1024)) МБ"
