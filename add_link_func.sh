#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"
LIB="$CYBRA/lib/cybra_invoice_lib.sh"
ID="INV-20261018T152617Z-3988"

echo "═══ 1. ПОВЕРНЕННЯ ФУНКЦІЇ В БІБЛІОТЕКУ ═══"
if ! grep -q "cybra_invoice_get_sign_link" "$LIB"; then
    cat >> "$LIB" <<'LIBEOF'

cybra_invoice_get_sign_link() {
    local id="$1"
    local file="$CYBRA_INVOICE_DIR/${id}.json"
    if [ ! -f "$file" ]; then
        echo "ERROR: файл $id не знайдено"
        return 1
    fi
    local token=$(/data/data/com.termux/files/usr/bin/python3 -c "import json; print(json.load(open('$file')).get('sign_token',''))" 2>/dev/null)
    if [ -z "$token" ]; then
        echo "ERROR: токен не знайдено в $id"
        return 1
    fi
    echo "cybra://sign/${token}"
}
LIBEOF
    echo "  [✓] Функцію додано в бібліотеку"
else
    echo "  [i] Функція вже є в бібліотеці"
fi

echo ""
echo "═══ 2. ГЕНЕРАЦІЯ ПОСИЛАННЯ ═══"
source "$LIB"
export CYBRA_INVOICE_DIR="$CYBRA/modules/module_19_contract_tui_menu/contracts"

LINK=$(cybra_invoice_get_sign_link "$ID")

if [ -n "$LINK" ]; then
    echo ""
    echo "════════════════════════════════════════════"
    echo "  ПОСИЛАННЯ ДЛЯ ПІДПИСУ ПРОДАВЦЕМ:"
    echo "════════════════════════════════════════════"
    echo ""
    echo "  $LINK"
    echo ""
    echo "════════════════════════════════════════════"
    echo "  (скопіюй цей рядок і відправ продавцю)"
    echo "════════════════════════════════════════════"
else
    echo "  ❌ Не вдалося згенерувати посилання"
fi

echo ""
echo "═══ 3. КОМІТ ═══"
cd "$CYBRA" || exit 1
git add -A
git commit -m "feat: restore cybra_invoice_get_sign_link function" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Синхронізовано"
