#!/data/data/com.termux/files/usr/bin/bash
SG="$HOME/CYBRA/selfgen/selfgen_core.py"
BRAIN="$HOME/CYBRA/brain/brain_core.py"

echo "═══ 1. ДОДАВАННЯ АВТО-КОМІТУ В SELFGEN (кожні 30с) ═══"

# Використовуємо sed для заміни time.sleep(60) на time.sleep(30) + auto_commit
python3 - <<'PYEOF'
from pathlib import Path
import re

# SelfGen
sg = Path.home() / "CYBRA/selfgen/selfgen_core.py"
text = sg.read_text()

# Додаємо функцію auto_commit перед daemon
if "def auto_commit():" not in text:
    func = '''
def auto_commit():
    r = run("git status --porcelain", cwd=CYBRA)
    if r.stdout.strip():
        run("git add -A", cwd=CYBRA)
        run(f"git commit -m 'selfgen: auto {datetime.now(timezone.utc).isoformat()}'", cwd=CYBRA)
        run("git push origin main", cwd=CYBRA)
        return len(r.stdout.splitlines())
    return 0

'''
    text = text.replace("def daemon():", func + "def daemon():")

# Замінюємо time.sleep(60) на auto_commit() + time.sleep(30)
text = re.sub(r'time\.sleep\(60\)', 'auto_commit()\n        time.sleep(30)', text)

sg.write_text(text)
print("  [✓] SelfGen оновлено (auto_commit кожні 30с)")

# Brain
brain = Path.home() / "CYBRA/brain/brain_core.py"
text = brain.read_text()

if "def auto_commit():" not in text:
    func = '''
def auto_commit():
    r = run("git status --porcelain", cwd=CYBRA)
    if r.stdout.strip():
        run("git add -A", cwd=CYBRA)
        run(f"git commit -m 'brain: auto {datetime.now(timezone.utc).isoformat()}'", cwd=CYBRA)
        run("git push origin main", cwd=CYBRA)
        return len(r.stdout.splitlines())
    return 0

'''
    text = text.replace("def daemon():", func + "def daemon():")

# Замінюємо time.sleep(120) на auto_commit() + time.sleep(60)
text = re.sub(r'time\.sleep\(120\)', 'auto_commit()\n        time.sleep(60)', text)

brain.write_text(text)
print("  [✓] Brain оновлено (auto_commit кожні 60с)")
PYEOF

echo ""
echo "═══ 2. ПЕРЕЗАПУСК ═══"
pm2 restart cybra-selfgen-daemon cybra-brain-daemon
echo "  [✓] Перезапущено"

echo ""
echo "═══ 3. ФІНАЛЬНИЙ КОМІТ ═══"
cd "$HOME/CYBRA" || exit 1
git add -A
git commit -m "feat: ultimate auto-commit in Brain and SelfGen" -q 2>/dev/null
git push origin main -q 2>/dev/null
echo "  [✓] Синхронізовано"

echo ""
echo "═══ 4. ПЕРЕВІРКА 100% ═══"
sleep 2
python3 "$HOME/CYBRA/check_100_percent.py"
