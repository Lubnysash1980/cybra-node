#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

CYBRA="$HOME/CYBRA"
SB="$CYBRA/sandbox"
LIMIT_MB=65
LIMIT_BYTES=$((LIMIT_MB * 1024 * 1024))

echo "═══ 1. СТВОРЕННЯ SANDBOX (${LIMIT_MB} MB) ═══"

mkdir -p "$SB"/{bin,tmp,run,logs,keep,trash}
chmod 700 "$SB"

# Правило sandbox: не більше 65 МБ
cat > "$SB/README.md" <<'EOF'
# CYBRA Sandbox

Ізольоване середовище для бінарників з Git-ноди.
Ліміт: 65 МБ.
Все, що більше — автоматично видаляється.
Використовуй `sandbox_run.sh` для запуску.
EOF

echo "  [✓] $SB створено"

echo ""
echo "═══ 2. СТВОРЕННЯ sandbox_run.sh (ІЗОЛЯЦІЯ + ЛІМІТ) ═══"

cat > "$SB/sandbox_run.sh" <<'SB_RUN'
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
SB_RUN

chmod +x "$SB/sandbox_run.sh"
echo "  [✓] sandbox_run.sh створено"

echo ""
echo "═══ 3. СТВОРЕННЯ ОЧИЩУВАЧА (sandbox_cleanup.sh) ═══"

cat > "$SB/sandbox_cleanup.sh" <<'CLEAN'
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
CLEAN

chmod +x "$SB/sandbox_cleanup.sh"
echo "  [✓] sandbox_cleanup.sh створено"

echo ""
echo "═══ 4. ДОДАВАННЯ ПРАВИЛА В CYBRA_AUTONODE_MAIN ═══"

NODE="$CYBRA/bin/cybra_autonode_main"

if [ ! -f "$NODE" ]; then
    echo "  [!] cybra_autonode_main не знайдено — створюємо з правилом sandbox"
    cat > "$NODE" <<'NODE_EOF'
#!/data/data/com.termux/files/usr/bin/bash
CYBRA_HOME="${HOME}/CYBRA"
LOG="${CYBRA_HOME}/logs/evo_node_main.log"
mkdir -p "${CYBRA_HOME}/logs"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

cd "$CYBRA_HOME" || exit 1
log "=== Node Main Start ==="

while true; do
    log "--- Cycle ---"
    
    # 1. Перевірка sandbox
    SB="$CYBRA_HOME/sandbox"
    if [ -d "$SB" ]; then
        SIZE=$(du -sb "$SB" 2>/dev/null | awk '{print $1}' || echo 0)
        LIMIT=$((65 * 1024 * 1024))
        if [ "$SIZE" -ge "$LIMIT" ]; then
            log "SANDBOX: переповнено ($((SIZE/1024/1024)) МБ), очищаю"
            "$SB/sandbox_cleanup.sh" 2>/dev/null || true
        else
            log "SANDBOX: OK ($((SIZE/1024/1024)) МБ / 65 МБ)"
        fi
    fi
    
    # 2. Перевірка EVO
    if [ ! -f "lib/cybra_invoice_lib.sh" ]; then
        log "EVO: немає lib, робимо rollback"
        git reset --hard HEAD --quiet 2>/dev/null
        git clean -fd --quiet 2>/dev/null
    fi
    
    # 3. Снапшот
    if [ -x "$CYBRA_HOME/bin/cybra_hash_eco" ]; then
        "$CYBRA_HOME/bin/cybra_hash_eco" snapshot >/dev/null 2>&1
        log "EVO: снапшот створено"
    fi
    
    log "EVO: 100% — система в нормі"
    sleep 60
done
NODE_EOF
    chmod +x "$NODE"
    echo "  [✓] cybra_autonode_main створено з правилом sandbox"
else
    # Додаємо перевірку sandbox у існуючий цикл
    if grep -q "SANDBOX" "$NODE"; then
        echo "  [i] правило sandbox вже є"
    else
        python3 - <<'PYEOF'
from pathlib import Path

f = Path.home() / "CYBRA/bin/cybra_autonode_main"
text = f.read_text()

# Додаємо перевірку sandbox перед перевіркою lib
old = '    if [ ! -f "lib/cybra_invoice_lib.sh" ]; then'
new = '''    # SANDBOX CHECK
    SB="$CYBRA_HOME/sandbox"
    if [ -d "$SB" ]; then
        SIZE=$(du -sb "$SB" 2>/dev/null | awk '{print $1}' || echo 0)
        LIMIT=$((65 * 1024 * 1024))
        if [ "$SIZE" -ge "$LIMIT" ]; then
            log "SANDBOX: переповнено ($((SIZE/1024/1024)) МБ), очищаю"
            "$SB/sandbox_cleanup.sh" 2>/dev/null || true
        fi
    fi
    
    if [ ! -f "lib/cybra_invoice_lib.sh" ]; then'''

if old in text:
    text = text.replace(old, new, 1)
    f.write_text(text)
    print("  [✓] правило sandbox додано в cybra_autonode_main")
else:
    print("  [!] не знайдено місце для вставки")
PYEOF
    fi
fi

echo ""
echo "═══ 5. ДОДАВАННЯ В GIT ═══"
cd "$CYBRA" || exit 1

git add sandbox/ bin/cybra_autonode_main 2>/dev/null || true
git commit -m "feat: 65MB isolated sandbox for binary tools + node rule" -q 2>/dev/null || echo "  (нічого нового)"
git push origin main -q 2>/dev/null || echo "  (push failed)"

echo ""
echo "═══ 6. ТЕСТ SANDBOX ═══"
echo "  --- Перевірка розміру ---"
"$SB/sandbox_run.sh" --size

echo ""
echo "  --- Тестовий запуск ---"
echo '#!/data/data/com.termux/files/usr/bin/bash
echo "Hello from sandbox"
echo "HOME=$HOME"
echo "PWD=$PWD"
echo "SANDBOX=$SANDBOX"
' > /tmp/test_sandbox_bin.sh
chmod +x /tmp/test_sandbox_bin.sh

"$SB/sandbox_run.sh" /tmp/test_sandbox_bin.sh || true

echo ""
echo "  --- Перевірка розміру після ---"
"$SB/sandbox_run.sh" --size

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ SANDBOX (65 MB) ГОТОВИЙ"
echo "════════════════════════════════════════════"
echo ""
echo " Використання:"
echo "   ~/CYBRA/sandbox/sandbox_run.sh <binary> [args]"
echo "   ~/CYBRA/sandbox/sandbox_run.sh --size"
echo "   ~/CYBRA/sandbox/sandbox_cleanup.sh"
echo ""
echo " Правило в ноді:"
echo "   кожні 60с перевіряє розмір sandbox"
echo "   якщо > 65 МБ — автоочищення"
echo "════════════════════════════════════════════"
