#!/data/data/com.termux/files/usr/bin/bash
# Збирає контекст для Нейро по модулю, обмежений $NEURO_CONTEXT_MB (default 4)
MOD="${1:-cybra-pool}"
LIMIT_MB="${NEURO_CONTEXT_MB:-4}"
OUT="barmenu/state/context_${MOD}.txt"
{
    echo "=== MODULE: $MOD ==="
    echo "=== TIME: $(date -Iseconds) ==="
    echo ""
    echo "--- SOURCE ---"
    find modules bin -name '*.js' -o -name '*.sh' 2>/dev/null | xargs wc -c 2>/dev/null | tail -1
    echo ""
    echo "--- LOGS (last 200) ---"
    pm2 logs "$MOD" --lines 200 --nostream 2>/dev/null
    echo ""
    echo "--- ENV (redacted) ---"
    grep -vE "API_KEY|PASS|SECRET|KEY=" .env 2>/dev/null
} > "$OUT"
SIZE=$(stat -c%s "$OUT" 2>/dev/null || echo 0)
MAX=$((LIMIT_MB * 1024 * 1024))
if [ "$SIZE" -gt "$MAX" ]; then
    tail -c "$MAX" "$OUT" > "${OUT}.trunc"
    mv "${OUT}.trunc" "$OUT"
fi
echo "📄 Контекст: $OUT ($(du -h "$OUT" | cut -f1), ліміт ${LIMIT_MB}MB)"
echo "💡 Для 65MB: export NEURO_CONTEXT_MB=65 (попередження: більшість AI мають ~0.8MB ліміту)"
