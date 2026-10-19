#!/data/data/com.termux/files/usr/bin/bash
# Контролер 152: перевіряє еволюцію, потім викликає main.sh
CYBRA="$HOME/CYBRA"
EVO_STATE="$CYBRA/evo/state/evo_state.json"

if [ -f "$EVO_STATE" ]; then
    EVO_OK=$(python3 -c "import json; print(json.load(open('$EVO_STATE')).get('ok', True))" 2>/dev/null)
    if [ "$EVO_OK" = "False" ]; then
        echo "⛔ Еволюція не пропустила (evo_state: not ok)"
        exit 1
    fi
fi

exec bash "$CYBRA/modules/module_152_rollback_evo/main.sh" "$@"
