#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 102: Binmix + 65MB бінарний простір
CYBRA="$HOME/CYBRA"
BINMIX="$CYBRA/bin/cybra_binmix"
SANDBOX="$CYBRA/sandbox"
LIMIT_MB=65
LIMIT_BYTES=$((LIMIT_MB * 1024 * 1024))
mkdir -p "$SANDBOX"/{bin,tmp,keep,trash,logs}

# ─── 65MB ПЕРЕВІРКА ───
check_sandbox() {
    local size=$(du -sb "$SANDBOX" 2>/dev/null | awk '{print $1}' || echo 0)
    local mb=$((size / 1024 / 1024))
    if [ "$size" -ge "$LIMIT_BYTES" ]; then
        echo "  ⚠️  Sandbox: ${mb}MB / ${LIMIT_MB}MB — очищаю"
        rm -rf "$SANDBOX"/trash/* "$SANDBOX"/tmp/* 2>/dev/null
        [ -x "$SANDBOX/sandbox_cleanup.sh" ] && "$SANDBOX/sandbox_cleanup.sh" >/dev/null 2>&1
        size=$(du -sb "$SANDBOX" 2>/dev/null | awk '{print $1}' || echo 0)
        mb=$((size / 1024 / 1024))
    fi
    echo "  📦 Sandbox: ${mb}MB / ${LIMIT_MB}MB"
}

# ─── ЗАГОЛОВОК ───
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [102] Binmix + 65MB Sandbox"
echo "════════════════════════════════════════════"

# ─── 65MB ───
echo "─── Бінарний простір ───"
check_sandbox

# ─── BINMIX ───
echo ""
echo "─── Binmix ───"
if [ -x "$BINMIX" ]; then
    "$BINMIX" status 2>/dev/null
else
    echo "  ❌ cybra_binmix не знайдено"
fi

echo ""
echo "════════════════════════════════════════════"
read -r -p "Натисни Enter для виходу..." _
