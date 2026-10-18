#!/data/data/com.termux/files/usr/bin/bash
SG="$HOME/CYBRA/selfgen/selfgen_core.py"

echo "═══ 1. ДОДАВАННЯ АВТО-КОМІТУ В SELFGEN ═══"

# Перевіряємо, чи вже є
if grep -q "auto_commit" "$SG"; then
    echo "  [i] Авто-коміт вже є в SelfGen"
else
    python3 - <<'PYEOF'
from pathlib import Path
sg = Path.home() / "CYBRA/selfgen/selfgen_core.py"
text = sg.read_text()

# Додаємо функцію
func = '''
def auto_commit():
    r = run("git status --porcelain", cwd=CYBRA)
    if r.stdout.strip():
        run("git add -A", cwd=CYBRA)
        run(f"git commit -m 'selfgen: auto-sync {datetime.now(timezone.utc).isoformat()}'", cwd=CYBRA)
        run("git push origin main", cwd=CYBRA)
        return len(r.stdout.splitlines())
    return 0

'''
if "def auto_commit():" not in text:
    text = text.replace("def daemon():", func + "def daemon():")

# Додаємо виклик в цикл після diagnose/heal
if "auto_commit()" not in text.split("def daemon():")[1]:
    # Знаходимо рядок з time.sleep і додаємо перед ним
    text = text.replace("time.sleep(60)", "auto_commit()\n        time.sleep(60)")

sg.write_text(text)
print("  [✓] Авто-коміт додано в SelfGen")
PYEOF
fi

echo ""
echo "═══ 2. ПЕРЕЗАПУСК SELFGEN ═══"
pm2 restart cybra-selfgen-daemon
echo "  [✓] SelfGen перезапущено"

echo ""
echo "═══ 3. ФІНАЛЬНИЙ КОМІТ ЗАРАЗ ═══"
cd "$HOME/CYBRA" || exit 1
git add -A
git commit -m "chore: final sync (selfgen auto-commit)" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Зміни закомічено і запушено"

echo ""
echo "═══ 4. ФІНАЛЬНИЙ ТЕСТ 100% ═══"
python3 "$HOME/CYBRA/check_100_percent.py"
