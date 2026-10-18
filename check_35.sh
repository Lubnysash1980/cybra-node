#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
echo "═══ 1. Що є в bin/ ═══"
ls -la "$MOD35/bin/"


echo ""
echo "═══ 2. Що є в vault/ ═══"
ls -la "$MOD35/vault/" 2>/dev/null || echo "vault/ не існує"

echo ""
echo "═══ 3. Перші 100 рядків guardian.sh ═══"
head -100 "$MOD35/bin/guardian.sh" 2>/dev/null || echo "guardian.sh не знайдено"

echo ""
echo "═══ 4. Запуск тесту module_35 (повний вивід) ═══"
bash "$MOD35/tests/run_tests.sh" 2>&1
