#!/data/data/com.termux/files/usr/bin/bash
# add_7levels_all.sh — додає 7 рівнів складності до ВСІХ скриптів
CYBRA="$HOME/CYBRA"

add_7levels() {
    local f="$1"
    [ -f "$f" ] || return
    grep -q "LEVEL1" "$f" && return  # вже є

    local name="$(basename "$f")"
    local level_file="$CYBRA/state/${name}.level"

    # Додаємо блок 7 рівнів ПЕРЕД останнім рядком (не в середину case)
    python3 - "$f" "$level_file" <<'PYEOF'
import sys
from pathlib import Path

f = Path(sys.argv[1])
level_file = sys.argv[2]
text = f.read_text()

block = f'''
# ─── 7 РІВНІВ СКЛАДНОСТІ ───
LEVEL_FILE="{level_file}"
level_now() {{ [ -f "$LEVEL_FILE" ] && cat "$LEVEL_FILE" || echo 1; }}
level_set() {{ echo "$1" > "$LEVEL_FILE"; }}
level1() {{ [ -d "$HOME/CYBRA" ] && return 0 || return 1; }}
level2() {{ command -v bash >/dev/null && return 0 || return 1; }}
level3() {{ [ -d "$HOME/CYBRA/modules" ] && return 0 || return 1; }}
level4() {{ [ -d "$HOME/CYBRA/logs" ] && return 0 || return 1; }}
level5() {{ [ -f "$HOME/CYBRA/evo/evo_core.py" ] && return 0 || return 1; }}
level6() {{ [ -d "$HOME/CYBRA/modules" ] && return 0 || return 1; }}
level7() {{ [ -d "$HOME/CYBRA/sandbox" ] && return 0 || return 1; }}
run_levels() {{
    local cur=$(level_now)
    for i in 1 2 3 4 5 6 7; do
        [ "$i" -lt "$cur" ] && continue
        if "level$i"; then level_set "$i"; else return 0; fi
    done
}}
run_levels
'''

# Вставляємо ПЕРЕД останнім рядком (не в case)
lines = text.rstrip().split("\n")
lines.insert(len(lines) - 1, block)
f.write_text("\n".join(lines) + "\n")
print(f"  [✓] {f.name}: 7 рівнів")
PYEOF
    chmod +x "$f"
}

echo "═══ ДОДАЮ 7 РІВНІВ ДО ВСІХ СКРИПТІВ ═══"

# 1. bin/
for f in "$CYBRA"/bin/*; do
    [ -f "$f" ] && [ -x "$f" ] && add_7levels "$f"
done

# 2. modules/*/main.sh
for f in "$CYBRA"/modules/*/main.sh; do
    [ -f "$f" ] && add_7levels "$f"
done

echo ""
echo "✅ Готово. Перевірка:"
grep -l "LEVEL1" "$CYBRA"/bin/* 2>/dev/null | wc -l | xargs echo "  bin/:"
grep -l "LEVEL1" "$CYBRA"/modules/*/main.sh 2>/dev/null | wc -l | xargs echo "  modules/:"
