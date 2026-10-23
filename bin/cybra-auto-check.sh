#!/data/data/com.termux/files/usr/bin/bash
# ГЕНЕРАЛЬНИЙ АУДИТ СИСТЕМИ CYBRA
CYBRA="$HOME/CYBRA"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"

OK="\033[1;32m✅\033[0m"
FAIL="\033[1;31m❌\033[0m"
WARN="\033[1;33m⚠️\033[0m"

echo -e "\n══════════════════════════════════════════════════"
echo -e " 🚀 ГЕНЕРАЛЬНИЙ АУДИТ СИСТЕМИ CYBRA"
echo -e "══════════════════════════════════════════════════"

# 1. Пакети
echo -e "\n─── 1. Системні пакети ───"
for pkg in sqlite3 node python3 git jq; do
    if command -v $pkg >/dev/null 2>&1; then
        echo -e "$OK $pkg встановлено"
    else
        echo -e "$FAIL $pkg ВІДСУТНІЙ (запустіть cybra-pkg-manager.sh)"
    fi
done

# 2. Моноліт та PM2
echo -e "\n─── 2. Моноліт та PM2 ───"
if command -v pm2 >/dev/null 2>&1; then
    if pm2 ls | grep -q "cybra-monolith.*online"; then
        echo -e "$OK Моноліт працює (online)"
    else
        echo -e "$FAIL Моноліт не запущений (виконайте: pm2 start bin/cybra-monolith.py)"
    fi
else
    echo -e "$FAIL PM2 не встановлено"
fi

# 3. Ключові скрипти та модулі
echo -e "\n─── 3. Ключові файли та модулі ───"
FILES=(
    "$CYBRA/bin/cybra-monolith.py:Моноліт"
    "$CYBRA/bin/fidic-engine.py:FIDIC Engine"
    "$CYBRA/bin/fidic-menu.sh:Меню FIDIC (160)"
    "$CYBRA/bin/cybra-link-manager.sh:Менеджер посилань (154)"
    "$CYBRA/modules/module_151_ad_contract/main.sh:Модуль 151 (Реклама)"
    "$CYBRA/modules/module_152_rollback_evo/main.sh:Модуль 152 (Відкат)"
)
for item in "${FILES[@]}"; do
    file="${item%%:*}"
    name="${item##*:}"
    if [ -f "$file" ]; then
        echo -e "$OK $name"
    else
        echo -e "$FAIL $name (Відсутній: $file)"
    fi
done

# 4. Інтеграція в меню TUI
echo -e "\n─── 4. Інтеграція в головне меню ───"
if [ -f "$MENU" ]; then
    for num in 151 152 154 160; do
        if grep -q "\[$num\]" "$MENU" && grep -q "$num)" "$MENU"; then
            echo -e "$OK Пункт [$num] інтегровано в меню"
        else
            echo -e "$FAIL Пункт [$num] ВІДСУТНІЙ у меню"
        fi
    done
    # Перевірка синтаксису меню
    if bash -n "$MENU" 2>/dev/null; then
        echo -e "$OK Синтаксис меню валідний"
    else
        echo -e "$FAIL Синтаксична помилка в меню!"
    fi
else
    echo -e "$FAIL Головне меню не знайдено!"
fi

# 5. База даних та FIDIC
echo -e "\n─── 5. Дані та База ───"
if [ -f "$CYBRA/data/ads.db" ]; then
    ADS_COUNT=$(sqlite3 "$CYBRA/data/ads.db" "SELECT COUNT(*) FROM ads;" 2>/dev/null || echo "?")
    echo -e "$OK База реклами (ads.db) — $ADS_COUNT записів"
else
    echo -e "$WARN База реклами (ads.db) ще не створена"
fi

FIDIC_COUNT=$(ls "$CYBRA/data/fidic/"*.json 2>/dev/null | wc -l)
if [ "$FIDIC_COUNT" -gt 0 ]; then
    echo -e "$OK FIDIC контракти — $FIDIC_COUNT шт."
else
    echo -e "$WARN FIDIC контракти відсутні"
fi

# 6. Синхронізація (Git)
echo -e "\n─── 6. Синхронізація з Нодою (Git) ───"
cd "$CYBRA" || exit
if git rev-parse --git-dir > /dev/null 2>&1; then
    COMMIT=$(git rev-parse --short HEAD 2>/dev/null)
    echo -e "$OK Git репозиторій активний (HEAD: $COMMIT)"
    if [ -f "$CYBRA/nodes/heartbeats/node_1.json" ]; then
        echo -e "$OK Heartbeat (пульс пристрою) присутній"
    else
        echo -e "$WARN Heartbeat не створено"
    fi
else
    echo -e "$FAIL Git не налаштований"
fi

echo -e "\n══════════════════════════════════════════════════"
echo -e " АУДИТ ЗАВЕРШЕНО"
echo -e "══════════════════════════════════════════════════\n"
