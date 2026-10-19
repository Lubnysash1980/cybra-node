#!/data/data/com.termux/files/usr/bin/bash
# МОДУЛЬ 152: Відкат до чистої ноти EVO
CYBRA="$HOME/CYBRA"
LOG="$CYBRA/logs/rollback_evo.log"
mkdir -p "$CYBRA/logs"

rollback_status() {
    echo ""
    echo "— Поточний стан —"
    [ -d "$CYBRA/.git" ] && echo "Git: $(cd "$CYBRA" && git rev-parse --short HEAD 2>/dev/null)"
    echo "EVO: $([ -f "$CYBRA/evo/evo_core.py" ] && echo 'є' || echo 'немає')"
    echo "Sandbox: $([ -d "$CYBRA/sandbox" ] && echo 'є' || echo 'немає')"
}
rollback_do() {
    echo ""
    read -r -p "Підтвердити відкат? (yes/no): " ok
    [ "$ok" != "yes" ] && echo "скасовано" && return
    [ -d "$CYBRA/.git" ] && (cd "$CYBRA" && git reset --hard HEAD --quiet 2>/dev/null) || true
    echo "✅ Відкат виконано"
    echo "[$(date -u +%FT%TZ)] ROLLBACK" >> "$LOG"
}

clear 2>/dev/null
while true; do
    echo ""
    echo "════════ 152. ВІДКАТ ДО ЧИСТОЇ НОТИ EVO ════════"
    echo "1) Стан  2) Відкат  0) Назад"
    read -r -p "Вибір: " c
    case "$c" in
        1) rollback_status ;;
        2) rollback_do ;;
        0) exit 0 ;;
        *) echo "невідомо" ;;
    esac
done
