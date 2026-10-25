#!/data/data/com.termux/files/usr/bin/bash
# parliament_evolve.sh — Відділ парламенту, що дописує систему (EVO)

CYBRA="$HOME/CYBRA"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
LOG="$CYBRA/logs/parliament_evolve.log"
mkdir -p "$CYBRA/logs"

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $1" >> "$LOG"; }

echo "═══ ПАРЛАМЕНТ: ЕВОЛЮЦІЯ СИСТЕМИ ═══"
echo ""

# ─── 1. Аналіз меню: які пункти не мають функцій ───
echo "--- Аналіз меню ---"
missing=()
for i in $(seq 1 150); do
    # Перевіряємо, чи є action_ функція для цього пункту
    if ! grep -q "action_[a-z0-9_]*" "$MENU" 2>/dev/null; then
        continue
    fi
    # Шукаємо в case виклик для цього пункту
    if ! grep -qE "^\s+$i\)" "$MENU" 2>/dev/null; then
        missing+=($i)
    fi
done

echo "Знайдено пунктів без обробки: ${#missing[@]}"
if [ ${#missing[@]} -gt 0 ]; then
    echo "Це: ${missing[*]}"
fi

# ─── 2. Генерація заглушок для відсутніх пунктів ───
echo ""
echo "--- Генерація обробників ---"
for i in "${missing[@]}"; do
    # Додаємо виклик у case (просто перед esac)
    sed -i "/^\s*esac/a\\        $i) action_generic_$i ;;" "$MENU"
    
    # Додаємо функцію-заглушку в кінець файлу (перед while true)
    cat >> "$MENU" <<EOF

action_generic_$i() {
    echo "Пункт [$i] в розробці"
    read -r _
}
EOF
    log "Створено заглушку для пункту $i"
    echo "  [✓] Пункт $i — створено"
done

# ─── 3. Коміт у Git ───
echo ""
echo "--- Коміт у Git ---"
cd "$CYBRA" || exit 1
git add "$MENU"
git commit -m "parliament: auto-generated handlers for missing menu items" -q
echo "  [✓] Закомічено"

echo ""
echo "═══ ГОТОВО ═══"
echo "Парламент дописав систему. Перевір меню:"
echo "  $MENU"
