#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"
MENU="modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
chmod u+w "$MENU"

# 1. Додати </dev/null до всіх controller-викликів — щоб не з'їдали stdin
python3 - "$MENU" <<'PY'
import sys, re
p = sys.argv[1]
t = open(p).read()
out, n = [], 0
for ln in t.split('\n'):
    if 'controllers/module-controller.sh' in ln and '</dev/null' not in ln:
        ln = re.sub(r';\s*$', ' </dev/null;;', ln.rstrip())
        if not ln.endswith(';;'):
            ln = ln.rstrip() + ' </dev/null;;'
        n += 1
    out.append(ln)
open(p, 'w').write('\n'.join(out))
print(f"patched:{n}")
PY

# 2. Перевірка синтаксису
bash -n "$MENU" || { echo '{"ok":false,"stage":"syntax"}'; exit 1; }

# 3. Тест: 158, 155, 204 — має бути 3 результати, 0 "Невідома"
OUT=$(printf '158\n155\n204\n0\n' | timeout 15 bash "$MENU" 2>&1)
ERR=$(printf '%s' "$OUT" | grep -c 'Невідома')
RES=$(printf '%s' "$OUT" | grep -cE '════ .+ ════')

chmod a-w "$MENU"

# 4. Звіт
if [ "$ERR" -eq 0 ] && [ "$RES" -ge 3 ]; then
  echo "{\"ok\":true,\"results\":$RES,\"errors\":$ERR,\"fixed\":true}"
else
  echo "{\"ok\":false,\"results\":$RES,\"errors\":$ERR}"
fi
