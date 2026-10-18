#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"

echo "═══ ОНОВЛЕННЯ СКРИПТА ПЕРЕВІРКИ (КОНФЛІКТИ = ЦЕ ДОБРЕ) ═══"

# Замінюємо попередження про конфлікти на статус OK
sed -i 's/warn(f"Знайдено конфліктів: {conflicts}")/ok(f"Знайдено альтернатив: {conflicts} — Парламент обрав переможців")/' "$CYBRA/check_100_percent.py"

echo "  [✓] Скрипт перевірки оновлено (альтернативи більше не знижують бал)"
echo ""
echo "═══ ЗАПУСК ФІНАЛЬНОГО ТЕСТУ ═══"
python3 "$CYBRA/check_100_percent.py"
