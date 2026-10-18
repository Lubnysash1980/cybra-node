#!/data/data/com.termux/files/usr/bin/bash

MOD35="$HOME/CYBRA/modules/module_35_cybra_guardian"
GUARDIAN="$MOD35/bin/guardian.sh"
VAULT="$MOD35/vault"

echo "═══ 1. ВИПРАВЛЕННЯ gd_verify ═══"

# Проблема: identity.env може мати IDENTITY_SALT, але gd_verify не використовує його
# Або хеші не збігаються через різні salt

python3 - <<'PYEOF'
from pathlib import Path

f = Path.home() / "CYBRA/modules/module_35_cybra_guardian/bin/guardian.sh"
text = f.read_text()

# Знаходимо функцію gd_verify і замінюємо на надійну версію
import re
pattern = re.compile(r'gd_verify\(\)\s*\{.*?\n\}', re.DOTALL)
match = pattern.search(text)

if not match:
    print("  [!] gd_verify не знайдено")
    exit(1)

new_func = '''gd_verify() {
    local name="${1:-}"
    local id_num="${2:-}"
    local wallet="${3:-}"
    local bio="${4:-none}"

    local id_file="$GUARD_VAULT/identity.env"
    [ ! -f "$id_file" ] && { echo "ERR: no identity"; return 1; }

    # Читаємо збережені хеші
    local stored_name_hash stored_id_hash stored_wallet_hash stored_bio_hash
    stored_name_hash="$(grep '^NAME_HASH=' "$id_file" 2>/dev/null | cut -d= -f2-)"
    stored_id_hash="$(grep '^ID_HASH=' "$id_file" 2>/dev/null | cut -d= -f2-)"
    stored_wallet_hash="$(grep '^WALLET_HASH=' "$id_file" 2>/dev/null | cut -d= -f2-)"
    stored_bio_hash="$(grep '^BIOMETRIC_HASH=' "$id_file" 2>/dev/null | cut -d= -f2-)"

    [ -z "$stored_name_hash" ] && { echo "ERR: no NAME_HASH"; return 1; }

    # Обчислюємо хеші введених даних
    local cur_name_hash cur_id_hash cur_wallet_hash cur_bio_hash
    cur_name_hash="$(gd_hash "$name")"
    cur_id_hash="$(gd_hash "$id_num")"
    cur_wallet_hash="$(gd_hash "$wallet")"
    cur_bio_hash="$(gd_hash "$bio")"

    # Порівнюємо
    local name_ok=0 id_ok=0 wallet_ok=0 bio_ok=0
    [ "$cur_name_hash" = "$stored_name_hash" ] && name_ok=1
    [ "$cur_id_hash" = "$stored_id_hash" ] && id_ok=1
    [ "$cur_wallet_hash" = "$stored_wallet_hash" ] && wallet_ok=1
    [ "$cur_bio_hash" = "$stored_bio_hash" ] && bio_ok=1

    if [ "$name_ok" = "1" ] && [ "$id_ok" = "1" ] && [ "$wallet_ok" = "1" ]; then
        echo "OK: identity verified"
        return 0
    fi

    echo "FAIL: identity mismatch"
    [ "$name_ok" = "0" ] && echo "  name mismatch"
    [ "$id_ok" = "0" ] && echo "  id mismatch"
    [ "$wallet_ok" = "0" ] && echo "  wallet mismatch"
    return 1
}'''

text = text[:match.start()] + new_func + text[match.end():]
f.write_text(text)
print("  [✓] gd_verify замінено на надійну версію")
PYEOF

echo ""
echo "═══ 2. ВИПРАВЛЕННЯ state pct ═══"
# Тест очікує 100%, але десь показує 14%. Треба знайти, звідки береться state_pct.

echo "  --- Шукаємо state_pct у guardian.sh ---"
grep -n "state_pct\|state_pct\|STATE_PCT" "$GUARDIAN" | head -10

echo ""
echo "  --- Шукаємо файл state_pct ---"
find "$MOD35" -name "*state_pct*" -o -name "*state*" -type f 2>/dev/null | head -10

echo ""
echo "  --- Вміст state/ ---"
ls -la "$MOD35/state/" 2>/dev/null

echo ""
echo "═══ 3. ПЕРЕВІРКА СИНТАКСИСУ ═══"
bash -n "$GUARDIAN" && echo "  [✓] OK" || echo "  [✗] Зламано"

echo ""
echo "═══ 4. ЗАПУСК ТЕСТУ ═══"
cd "$MOD35" || exit 1
rm -f "$VAULT/identity.env"
bash "$MOD35/tests/run_tests.sh" 2>&1 | tail -30
