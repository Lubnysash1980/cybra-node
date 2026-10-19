#!/data/data/com.termux/files/usr/bin/bash
export HOME="/data/data/com.termux/files/home"
# Контролер 151: перевіряє еволюцію, потім викликає main.sh
CYBRA="$HOME/CYBRA"
EVO_STATE="$CYBRA/evo/state/evo_state.json"
LEVEL_FILE="$CYBRA/state/module_151.level"

# 1. Перевірка еволюції
if [ -f "$EVO_STATE" ]; then
    EVO_OK=$(python3 -c "import json; print(json.load(open('$EVO_STATE')).get('ok', True))" 2>/dev/null)
    if [ "$EVO_OK" = "False" ]; then
        echo "⛔ Еволюція не пропустила (evo_state: not ok)"
        exit 1
    fi
fi

# 2. Перевірка рівня (не вище 7)
LEVEL=$(cat "$LEVEL_FILE" 2>/dev/null || echo 1)
if [ "$LEVEL" -gt 7 ]; then
    echo "⛔ Рівень $LEVEL > 7 — не пропускаємо"
    exit 1
fi

# 3. Виклик main.sh
exec bash "$CYBRA/modules/module_151_ad_contract/main.sh" "$@"
