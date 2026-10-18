#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

SB="$HOME/CYBRA/sandbox"
LIMIT_MB=65
LIMIT_BYTES=$((LIMIT_MB * 1024 * 1024))

# Перевірка розміру
current_size() {
    du -sb "$SB" 2>/dev/null | awk '{print $1}' || echo 0
}

ensure_space() {
    local size
    size="$(current_size)"
    if [ "$size" -ge "$LIMIT_BYTES" ]; then
        echo "⚠ Sandbox переповнено ($((size/1024/1024)) МБ / ${LIMIT_MB} МБ). Очищаю..."
        # Видаляємо старі файли з trash, потім tmp, потім bin
        rm -rf "$SB"/trash/* 2>/dev/null || true
        rm -rf "$SB"/tmp/* 2>/dev/null || true
        
        # Якщо все ще переповнено — видаляємо найстаріші бінарники
        size="$(current_size)"
        if [ "$size" -ge "$LIMIT_BYTES" ]; then
            find "$SB/bin" -type f -printf '%T@ %p\n' 2>/dev/null | \
                sort -n | \
                head -5 | \
                awk '{print $2}' | \
                while read -r f; do
                    echo "  removing: $f"
                    rm -f "$f"
                done
        fi
    fi
}

if [ $# -eq 0 ]; then
    echo "Usage: sandbox_run.sh <binary> [args...]"
    echo "   or: sandbox_run.sh --size"
    exit 1
fi

if [ "$1" = "--size" ]; then
    size="$(current_size)"
    echo "Sandbox: $((size/1024/1024)) МБ / ${LIMIT_MB} МБ"
    echo "Files:"
    find "$SB" -type f -exec ls -lh {} \; 2>/dev/null | awk '{print "  "$5" "$9}'
    exit 0
fi

BIN="$1"
shift

if [ ! -f "$BIN" ]; then
    echo "❌ Бінарник не знайдено: $BIN"
    exit 1
fi

# Перевірка розміру бінарника
BIN_SIZE=$(stat -c%s "$BIN" 2>/dev/null || echo 0)
if [ "$BIN_SIZE" -gt "$LIMIT_BYTES" ]; then
    echo "❌ Бінарник завеликий: $((BIN_SIZE/1024/1024)) МБ > ${LIMIT_MB} МБ"
    exit 1
fi

ensure_space

# Копіюємо бінарник у sandbox
TARGET="$SB/bin/$(basename "$BIN")"
cp "$BIN" "$TARGET"
chmod +x "$TARGET"

echo "▶ Запуск у sandbox: $(basename "$TARGET")"

# Ізольоване середовище
export HOME="$SB/tmp"
export TMPDIR="$SB/tmp"
export PATH="$SB/bin:/data/data/com.termux/files/usr/bin:/data/data/com.termux/files/usr/bin"
export SANDBOX=1

# Запуск з обмеженням часу (60с) і пам'яті
timeout 60s "$TARGET" "$@" 2>&1 | tee "$SB/logs/$(basename "$TARGET").log"

RC=$?

echo "⏹ Завершено (exit=$RC)"

# Після запуску: якщо RC != 0 — перемістити в trash
if [ "$RC" -ne 0 ]; then
    mv "$TARGET" "$SB/trash/" 2>/dev/null || true
    echo "  → переміщено в trash (помилка)"
else
    # Успішно — залишити в keep
    mv "$TARGET" "$SB/keep/" 2>/dev/null || true
    echo "  → збережено в keep"
fi

exit $RC
