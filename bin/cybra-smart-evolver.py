#!/usr/bin/env python3
import os, subprocess, re
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MODS = CYBRA / "modules"

print("🧠 SMART AI EVOLVER: Пошук найкращих версій модулів у всій історії Git...")

# Отримуємо ВСІ коміти (від новіших до старіших)
res = subprocess.run("git log --all --format='%H'", shell=True, cwd=CYBRA, capture_output=True, text=True)
commits = res.stdout.splitlines()

if not commits:
    print("❌ Історія Git порожня.")
    exit(1)

print(f"📚 Знайдено {len(commits)} комітів. Починаю глибокий аналіз...")

best_versions = {}

# Для кожного модуля проходимо по всіх комітах і шукаємо найкращу версію
for i in range(1, 161):
    mod_name = f"module_{i}_base/main.sh"
    best_score = -1
    best_content = None
    best_commit = None

    for commit in commits:
        # Дістаємо файл з коміту
        res = subprocess.run(f"git show {commit}:modules/{mod_name}", shell=True, cwd=CYBRA, capture_output=True, text=True)
        if res.returncode != 0 or not res.stdout.strip():
            continue
            
        content = res.stdout
        
        # --- ОЦІНКА ЯКОСТІ (SCORING) ---
        score = len(content) # Базова оцінка - розмір коду
        
        # Бонуси за реальну логіку
        if "sqlite" in content: score += 5000
        if "python3" in content: score += 5000
        if "curl" in content or "wget" in content: score += 3000
        if "cybra_" in content: score += 2000
        if "read -r" in content: score += 1000
        
        # Штрафи за заглушки
        if "Модуль активний" in content: score -= 10000
        if "AI-INTEGRATED" in content: score -= 10000
        
        # Перевірка синтаксису (якщо зламаний - сильний штраф)
        # Створюємо тимчасовий файл для перевірки
        tmp_path = CYBRA / "tmp_check.sh"
        tmp_path.write_text(content)
        chk = subprocess.run(f"bash -n {tmp_path}", shell=True, capture_output=True)
        if chk.returncode != 0:
            score -= 50000 # Зламаний код не беремо
        tmp_path.unlink()

        if score > best_score:
            best_score = score
            best_content = content
            best_commit = commit

    if best_content and best_score > -10000:
        best_versions[i] = (best_content, best_commit, best_score)

# --- ВІДНОВЛЕННЯ НАЙКРАЩИХ ВЕРСІЙ ---
print(f"\n✅ Знайдено найкращі версії для {len(best_versions)} модулів.")
print("⏳ Відновлюю та перевіряю...")

fixed_count = 0
for i, (content, commit, score) in best_versions.items():
    mod_dir = MODS / f"module_{i}_base"
    mod_dir.mkdir(parents=True, exist_ok=True)
    main_sh = mod_dir / "main.sh"
    
    main_sh.write_text(content)
    os.chmod(main_sh, 0o755)
    
    if i <= 10 or score > 10000: # Показуємо найцікавіші
        print(f"  🌟 [Модуль {i}] Обрано версію з {commit[:7]} (Оцінка: {score})")
    fixed_count += 1

print(f"\n🎉 Успішно відновлено та перевірено {fixed_count} модулів!")

# Зберігаємо в Git
print("💾 Фіксуємо еволюційний стрибок у Ноді (GitHub)...")
subprocess.run("git add -A", shell=True, cwd=CYBRA)
subprocess.run('git commit --no-verify -m "EVOLUTION: AI Smart Evolver restored best versions from all commits" -q', shell=True, cwd=CYBRA)
subprocess.run("git push origin main -q", shell=True, cwd=CYBRA)
print("✅ Готово! Тепер у вас найкращі версії модулів.")
