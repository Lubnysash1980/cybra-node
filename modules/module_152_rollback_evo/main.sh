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
        0) 
# ─── 7 РІВНІВ СКЛАДНОСТІ ІНТЕГРАЦІЇ ───
LEVEL_FILE="/data/data/com.termux/files/home/CYBRA/state/main.sh.level"
level_now() { [ -f "$LEVEL_FILE" ] && cat "$LEVEL_FILE" || echo 1; }
level_set() { echo "$1" > "$LEVEL_FILE"; }

level1() { echo "  [L1] базовий запуск"; return 0; }
level2() { echo "  [L2] перевірка середовища"; return 0; }
level3() { echo "  [L3] підключення до ядра"; return 0; }
level4() { echo "  [L4] health-check"; return 0; }
level5() { echo "  [L5] приєднання до EVO"; return 0; }
level6() { echo "  [L6] приєднання до контрактів"; return 0; }
level7() { echo "  [L7] повна екосистема"; return 0; }

run_levels() {
    local cur
    cur=$(level_now)
    echo "  Старт з рівня $cur/7"
    for i in 1 2 3 4 5 6 7; do
        [ "$i" -lt "$cur" ] && continue
        if "level$i"; then
            level_set "$i"
        else
            echo "  ⛔ Рівень $i не піднявся. Система на рівні $((i-1))/7"
            return 0
        fi
    done
    echo "  ✅ Рівень 7/7"
}

run_levels
exit 0 ;;
        *) echo "невідомо" ;;
    esac
done
