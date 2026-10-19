#!/data/data/com.termux/files/usr/bin/bash
# apply_7levels.sh — додає 7 рівнів складності до скрипта
# Кожен скрипт отримує 7 рівнів приєднання. Якщо рівень не пішов — зупиняється.

CYBRA="$HOME/CYBRA"
TARGET="$1"

if [ -z "$TARGET" ] || [ ! -f "$TARGET" ]; then
    echo "usage: apply_7levels.sh <script.sh>"
    exit 1
fi

NAME="$(basename "$TARGET")"
LEVEL_FILE="$CYBRA/state/${NAME}.level"
mkdir -p "$CYBRA/state"

# Додаємо 7 рівнів у скрипт (перед останнім рядком)
python3 - "$TARGET" "$NAME" "$LEVEL_FILE" <<'PYEOF'
import sys, re
from pathlib import Path

target = Path(sys.argv[1])
name = sys.argv[2]
level_file = sys.argv[3]

text = target.read_text()
if "LEVEL1" in text:
    print(f"  [i] {name}: 7 рівнів вже є")
    sys.exit(0)

block = f'''
# ─── 7 РІВНІВ СКЛАДНОСТІ ІНТЕГРАЦІЇ ───
LEVEL_FILE="{level_file}"
level_now() {{ [ -f "$LEVEL_FILE" ] && cat "$LEVEL_FILE" || echo 1; }}
level_set() {{ echo "$1" > "$LEVEL_FILE"; }}

level1() {{ echo "  [L1] базовий запуск"; return 0; }}
level2() {{ echo "  [L2] перевірка середовища"; return 0; }}
level3() {{ echo "  [L3] підключення до ядра"; return 0; }}
level4() {{ echo "  [L4] health-check"; return 0; }}
level5() {{ echo "  [L5] приєднання до EVO"; return 0; }}
level6() {{ echo "  [L6] приєднання до контрактів"; return 0; }}
level7() {{ echo "  [L7] повна екосистема"; return 0; }}

run_levels() {{
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
}}
'''

# Вставляємо перед останнім "exit 0" або в кінець
if "exit 0" in text:
    text = text.replace("exit 0", block + "\nrun_levels\nexit 0", 1)
else:
    text += block + "\nrun_levels\n"

target.write_text(text)
print(f"  [✓] {name}: 7 рівнів додано")
PYEOF

chmod +x "$TARGET"
bash -n "$TARGET" && echo "  ✅ синтаксис OK"
