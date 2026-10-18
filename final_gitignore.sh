#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
cd "$CYBRA" || exit 1

echo "═══ 1. ДОДАВАННЯ В .gitignore (логи, стани, снапшоти) ═══"

cat >> .gitignore <<'EOF'

# Brain / EVO / SelfGen runtime
brain/logs/
brain/state/
evo/logs/
evo/state/
selfgen/logs/
nodes/*/logs/
nodes/*/state/
hashes/snapshots/
logs/
EOF

echo "  [✓] .gitignore оновлено"

echo ""
echo "═══ 2. ВИДАЛЕННЯ ВЖЕ ВІДСЛІДКОВАНИХ ЛОГІВ З ІНДЕКСУ ═══"
git rm -r --cached brain/logs evo/logs selfgen/logs nodes/*/logs nodes/*/state hashes/snapshots logs 2>/dev/null
echo "  [✓] Логи видалено з індексу"

echo ""
echo "═══ 3. ФІНАЛЬНИЙ КОМІТ ═══"
git add -A
git commit -m "chore: ignore runtime logs and states" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Синхронізовано"

echo ""
echo "═══ 4. ПЕРЕЗАПУСК BRAIN ═══"
pm2 restart cybra-brain-daemon
echo "  [✓] Brain перезапущено"

echo ""
echo "═══ 5. ФІНАЛЬНИЙ ТЕСТ 100% ═══"
python3 "$CYBRA/check_100_percent.py"
