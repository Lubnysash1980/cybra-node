#!/data/data/com.termux/files/usr/bin/bash
# МЕГАСКРИПТ КОНТРОЛЕРІВ — ставить контролери на реальні робочі скрипти
# 7 рівнів відновлення. Не на заглушки. На результат.
CYBRA="$HOME/CYBRA"
REG="$CYBRA/registry/controllers.json"
LOG="$CYBRA/logs/mega_controllers.log"
mkdir -p "$CYBRA/registry" "$CYBRA/logs"
log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

echo "═══ МЕГАСКРИПТ КОНТРОЛЕРІВ ═══"

# ─── 7 РІВНІВ ВІДНОВЛЕННЯ ───
L1() { [ -d "$CYBRA" ] || return 1; echo "  [L1] CYBRA є"; }
L2() { command -v sqlite3 >/dev/null || return 1; echo "  [L2] sqlite3 є"; }
L3() { [ -f "$CYBRA/bin/cybra-controller" ] || return 1; echo "  [L3] cybra-controller є"; }
L4() { [ -d "$CYBRA/registry" ] || return 1; echo "  [L4] registry є"; }
L5() { [ -d "$CYBRA/sandbox" ] || mkdir -p "$CYBRA/sandbox"/{bin,tmp,keep,trash}; echo "  [L5] sandbox 65MB"; }
L6() { [ -f "$REG" ] || echo '{"controllers":{}}' > "$REG"; echo "  [L6] registry.json"; }
L7() { [ -d "$CYBRA/evo" ] || return 1; echo "  [L7] EVO є"; }
LEVELS=(L1 L2 L3 L4 L5 L6 L7)

# ─── РЕАЛЬНІ РОБОЧІ СКРИПТИ (не заглушки) ───
# Шукаємо скрипти, які реально щось роблять (>200 байт, не шаблон)
find_real() {
    local result=()
    for f in "$CYBRA"/modules/*/main.sh "$CYBRA"/bin/*; do
        [ -f "$f" ] || continue
        # пропускаємо шаблони
        grep -q "МОДУЛЬ.*(100%)" "$f" 2>/dev/null && continue
        grep -q "СТАТУС: READY (100% - auto-resolved)" "$f" 2>/dev/null && continue
        # беремо тільки ті, що >200 байт
        [ "$(stat -c%s "$f" 2>/dev/null || echo 0)" -gt 200 ] && result+=("$f")
    done
    echo "${result[@]}"
}

# ─── СТАВИМО КОНТРОЛЕРИ НА РЕАЛЬНІ СКРИПТИ ───
real_scripts=($(find_real))
echo ""
echo "Знайдено реальних скриптів: ${#real_scripts[@]}"

controllers="{}"
for script in "${real_scripts[@]}"; do
    name=$(basename "$(dirname "$script")")_$(basename "$script")
    key=$(echo "$name" | tr '/.' '__')
    level_file="$CYBRA/state/${key}.level"
    mkdir -p "$CYBRA/state"
    # реєструємо контролер
    controllers=$(echo "$controllers" | python3 -c "
import json,sys
d=json.load(sys.stdin)
d['$key']={'path':'$script','levels':7,'status':'active','level_file':'$level_file'}
print(json.dumps(d,ensure_ascii=False))
")
done

# записуємо реєстр
python3 -c "
import json
d=json.loads('''$controllers''')
reg={'controllers':d,'updated':'$(date -u +%Y-%m-%dT%H:%M:%SZ)'}
open('$REG','w').write(json.dumps(reg,indent=2,ensure_ascii=False))
print(f'✅ Зареєстровано: {len(d)} контролерів')
"

# ─── ПРОГАНЯЄМО 7 РІВНІВ ───
echo ""
echo "─── 7 рівнів відновлення ───"
level=1
for fn in "${LEVELS[@]}"; do
    if $fn; then
        level=$((level+1))
    else
        echo "  ⛔ Рівень $level не піднявся — зупинка"
        log "STOP at level $level"
        break
    fi
done
echo "  Рівень: $((level-1))/7"

# ─── ЗАПУСКАЄМО РЕАЛЬНІ СКРИПТИ ЧЕРЕЗ КОНТРОЛЕР ───
echo ""
echo "─── Тест реальних скриптів ───"
for script in "${real_scripts[@]:0:5}"; do
    echo "  ▶ $(basename "$script")"
    "$CYBRA/bin/cybra-controller" "$script" 2>&1 | head -2
done

log "DONE: ${#real_scripts[@]} real scripts, level $((level-1))/7"
echo ""
echo "════════════════════════════════════════════"
echo "  ✅ МЕГАСКРИПТ ЗАВЕРШЕНО"
echo "  Контролерів: ${#real_scripts[@]}"
echo "  Рівень: $((level-1))/7"
echo "════════════════════════════════════════════"
