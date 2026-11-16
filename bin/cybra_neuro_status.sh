#!/data/data/com.termux/files/usr/bin/bash
echo "🏛️ CYBRA NEURO DEPARTMENT STATUS"
echo "--------------------------------"
if [ -f "parliament/committees/neuro_department/committee.json" ]; then
    echo "✅ Маніфест: Знайдено"
else
    echo "❌ Маніфест: Відсутній"
fi

echo ""
echo "📊 Останні виправлення:"
if [ -f "data/cybra_neuro_department/reports/fixes.jsonl" ]; then
    tail -n 3 data/cybra_neuro_department/reports/fixes.jsonl
else
    echo "  (ще немає звітів)"
fi

echo ""
echo "⚙️ Процеси:"
pm2 describe cybra-brain | grep -E "status|uptime" || echo "  cybra-brain: not running"
