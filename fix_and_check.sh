#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"

echo "═══ 1. ВСТАНОВЛЕННЯ QRENCODE ═══"
pkg install -y libqrencode >/dev/null 2>&1
if command -v qrencode >/dev/null; then
    echo "  [✓] qrencode встановлено"
else
    echo "  [!] Не вдалося встановити qrencode"
fi

echo ""
echo "═══ 2. ВІДНОВЛЕННЯ GIT REMOTE ═══"
cd "$CYBRA" || exit 1
if ! git remote -v | grep -q origin; then
    git remote add origin https://github.com/Lubnysash1980/cybra-node.git
    echo "  [✓] Git remote 'origin' додано"
else
    echo "  [✓] Git remote вже налаштовано"
fi

echo ""
echo "═══ 3. ПЕРЕЗАПУСК PM2 ═══"
pm2 delete all 2>/dev/null
pm2 start "$CYBRA/ecosystem.config.js"
pm2 save 2>/dev/null
echo "  [✓] PM2 перезапущено"

echo ""
echo "═══ 4. ВИПРАВЛЕННЯ PYTHON-СКРИПТА (import re) ═══"
# Додаємо import re на початок скрипта, якщо його там немає
if ! grep -q "^import re" "$CYBRA/check_100_percent.py"; then
    sed -i '1s/^/import re\n/' "$CYBRA/check_100_percent.py"
    echo "  [✓] Модуль 're' імпортовано в скрипт перевірки"
fi

echo ""
echo "═══ 5. ЗАПУСК ТЕСТУ 100% ═══"
python3 "$CYBRA/check_100_percent.py"

echo ""
echo "════════════════════════════════════════════"
echo "  ГОТОВО. Якщо тест показав 95%+, система стабільна."
echo "════════════════════════════════════════════"
