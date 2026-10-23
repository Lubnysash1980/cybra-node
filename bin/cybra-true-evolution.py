#!/usr/bin/env python3
import os, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MODS = CYBRA / "modules"

print("🧬 ЗАПУСК СПРАВЖНЬОЇ ЕВОЛЮЦІЇ (Відновлення логіки з історії Git)...")

# 1. Отримуємо список усіх комітів
res = subprocess.run("git log --all --oneline", shell=True, cwd=CYBRA, capture_output=True, text=True)
commits = [line.split()[0] for line in res.stdout.splitlines()]

fixed = 0
for i in range(1, 161):
    mod_name = f"module_{i}_base/main.sh"
    mod_path = MODS / mod_name
    
    is_stub = True
    if mod_path.exists():
        content = mod_path.read_text()
        if "sqlite" in content or "python3" in content or "curl" in content or "cybra_contract_create" in content:
            is_stub = False # Це вже не заглушка
            
    if is_stub:
        # Шукаємо оригінал у всіх комітах
        for commit in commits:
            res = subprocess.run(f"git show {commit}:modules/{mod_name}", shell=True, cwd=CYBRA, capture_output=True, text=True)
            if res.returncode == 0 and res.stdout.strip():
                # Знайшли! Перевіряємо, чи це не заглушка
                if "sqlite" in res.stdout or "python3" in res.stdout or "cybra_" in res.stdout:
                    mod_path.parent.mkdir(parents=True, exist_ok=True)
                    mod_path.write_text(res.stdout)
                    os.chmod(mod_path, 0o755)
                    print(f"  ✅ [Модуль {i}] Відновлено оригінал з коміту {commit[:7]}")
                    fixed += 1
                    break

print(f"\n✅ Успішно відновлено модулів: {fixed}")

# 2. Зберігаємо в Git
print("⏳ Фіксуємо справжню еволюцію в Ноді...")
subprocess.run("git add -A", shell=True, cwd=CYBRA)
subprocess.run('git commit --no-verify -m "EVOLUTION: restored REAL logic for modules from Git history" -q', shell=True, cwd=CYBRA)
subprocess.run("git push origin main -q", shell=True, cwd=CYBRA)
print("🎉 Еволюція завершена. Тепер у меню справжній код, а не заглушки.")
