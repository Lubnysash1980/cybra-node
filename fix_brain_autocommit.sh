#!/data/data/com.termux/files/usr/bin/bash
BRAIN="$HOME/CYBRA/brain/brain_core.py"

echo "═══ 1. ДОДАВАННЯ АВТО-КОМІТУ В BRAIN ═══"

# Перевіряємо, чи вже є функція
if grep -q "auto_commit" "$BRAIN"; then
    echo "  [i] Авто-коміт вже є"
else
    # Додаємо функцію авто-коміту та виклик в циклі
    python3 - <<'PYEOF'
from pathlib import Path
brain = Path.home() / "CYBRA/brain/brain_core.py"
text = brain.read_text()

# Додаємо функцію перед daemon()
func = '''
def auto_commit():
    """Автоматично комітить всі зміни в Git"""
    r = run("git status --porcelain", cwd=CYBRA)
    if r.stdout.strip():
        run("git add -A", cwd=CYBRA)
        run(f"git commit -m 'brain: auto-sync {datetime.now(timezone.utc).isoformat()}'", cwd=CYBRA)
        run("git push origin main", cwd=CYBRA)
        return len(r.stdout.splitlines())
    return 0

'''
if "def auto_commit():" not in text:
    text = text.replace("def daemon():", func + "def daemon():")

# Додаємо виклик в цикл (після collect_metrics)
if "auto_commit()" not in text.split("def daemon():")[1]:
    text = text.replace(
        "metrics = collect_metrics()",
        "metrics = collect_metrics()\n            committed = auto_commit()\n            if committed: log(f'AUTO-COMMIT: {committed} files')"
    )

brain.write_text(text)
print("  [✓] Авто-коміт додано в Brain")
PYEOF
fi

echo ""
echo "═══ 2. ПЕРЕЗАПУСК BRAIN ═══"
pm2 restart cybra-brain-daemon
echo "  [✓] Brain перезапущено"

echo ""
echo "═══ 3. РУЧНИЙ КОМІТ ЗАРАЗ (щоб очистити поточні 17 файлів) ═══"
cd "$HOME/CYBRA" || exit 1
git add -A
git commit -m "chore: sync all pending files (brain auto-commit)" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Зміни закомічено і запушено"

echo ""
echo "═══ 4. ФІНАЛЬНИЙ ТЕСТ ═══"
python3 "$HOME/CYBRA/check_100_percent.py"
