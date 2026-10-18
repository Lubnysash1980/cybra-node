#!/data/data/com.termux/files/usr/bin/bash

MOD35="$HOME/CYBRA/modules/module_35_cybra_guardian"
GUARDIAN="$MOD35/bin/guardian.sh"

echo "═══ 1. ВИПРАВЛЕННЯ gd_register (IDENTITY_SALT) ═══"

# Додаємо генерацію IDENTITY_SALT перед використанням
python3 - <<'PYEOF'
from pathlib import Path

f = Path.home() / "CYBRA/modules/module_35_cybra_guardian/bin/guardian.sh"
text = f.read_text()

# Замінюємо problematic рядок
old = 'IDENTITY_SALT=$IDENTITY_SALT'
new = 'IDENTITY_SALT=$(head -c 16 /dev/urandom | od -An -tx1 | tr -d " \\n")'

if old in text:
    text = text.replace(old, new)
    f.write_text(text)
    print("  [✓] Замінено IDENTITY_SALT на генерацію")
else:
    print("  [!] Рядок IDENTITY_SALT=$IDENTITY_SALT не знайдено")
PYEOF

echo ""
echo "═══ 2. ПЕРЕВІРКА СИНТАКСИСУ ═══"
bash -n "$GUARDIAN" && echo "  [✓] OK" || echo "  [✗] Зламано"

echo ""
echo "═══ 3. ЗАПУСК ТЕСТУ ═══"
cd "$MOD35" || exit 1

# Очищуємо попередній порожній identity.env
rm -f "$MOD35/vault/identity.env"

bash "$MOD35/tests/run_tests.sh" 2>&1 | tail -40
