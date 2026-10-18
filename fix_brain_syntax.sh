#!/data/data/com.termux/files/usr/bin/bash
BRAIN="$HOME/CYBRA/brain/brain_core.py"

echo "═══ 1. ВИПРАВЛЕННЯ BRAIN ═══"

# Перевіряємо синтаксис Python
if ! python3 -m py_compile "$BRAIN" 2>/dev/null; then
    echo "  🔴 Синтаксис Brain зламано. Відновлюємо з Git."
    cd "$HOME/CYBRA" || exit 1
    git checkout HEAD -- brain/brain_core.py
    echo "  [✓] Brain відновлено з Git"
else
    echo "  [✓] Синтаксис Brain OK"
fi

echo ""
echo "═══ 2. ПЕРЕЗАПУСК BRAIN ═══"
pm2 restart cybra-brain-daemon
echo "  [✓] Brain перезапущено"

echo ""
echo "═══ 3. ПЕРЕВІРКА PM2 ═══"
sleep 2
pm2 status

echo ""
echo "═══ 4. ФІНАЛЬНИЙ КОМІТ (якщо є зміни) ═══"
cd "$HOME/CYBRA" || exit 1
git add -A
git commit -m "fix: restore brain after auto-commit patch" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Синхронізовано"

echo ""
echo "═══ 5. ПЕРЕВІРКА 100% ═══"
python3 "$HOME/CYBRA/check_100_percent.py"
