#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 102: Binmix + 65MB
CYBRA="$HOME/CYBRA"
SANDBOX="$CYBRA/sandbox"
BINMIX="$CYBRA/bin/cybra_binmix"
LIMIT_MB=65
LIMIT_BYTES=$((LIMIT_MB * 1024 * 1024))
mkdir -p "$SANDBOX"/{bin,tmp,keep,trash,logs}
check_sandbox() {
    local size=$(du -sb "$SANDBOX" 2>/dev/null | awk '{print $1}' || echo 0)
    local mb=$((size / 1024 / 1024))
    if [ "$size" -ge "$LIMIT_BYTES" ]; then
        echo "  ⚠️  Sandbox: ${mb}MB / ${LIMIT_MB}MB — очищаю"
        rm -rf "$SANDBOX"/trash/* "$SANDBOX"/tmp/* 2>/dev/null
    fi
    echo "  📦 Sandbox: ${mb}MB / ${LIMIT_MB}MB"
}
clear 2>/dev/null
echo "════════════════════════════════════════════"
echo "  [102] Binmix + 65MB Sandbox"
echo "════════════════════════════════════════════"
echo "─── Бінарний простір ───"
check_sandbox
echo ""
echo "─── Binmix ───"
[ -x "$BINMIX" ] && "$BINMIX" status 2>/dev/null || echo "  ❌ cybra_binmix"
echo ""
read -r -p "Натисни Enter..." _
