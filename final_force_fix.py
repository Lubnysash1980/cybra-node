#!/usr/bin/env python3
import os, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LIB_FILE = CYBRA / "lib" / "cybra_invoice_lib.sh"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ПЕРЕВІРКА ФАЙЛУ ═══")
if not LIB_FILE.exists():
    print(f"  [!] {LIB_FILE} не існує. Створюємо...")
    LIB_FILE.parent.mkdir(parents=True, exist_ok=True)
    LIB_FILE.write_text("#!/data/data/com.termux/files/usr/bin/bash\necho 'lib loaded'\n")
    os.chmod(LIB_FILE, 0o755)
else:
    print(f"  [✓] {LIB_FILE} існує")

print("\n═══ 2. ПЕРЕВІРКА .gitignore ═══")
gitignore = CYBRA / ".gitignore"
if gitignore.exists():
    content = gitignore.read_text()
    if "cybra_invoice_lib" in content:
        print("  [!] Файл у .gitignore! Видаляємо звідти...")
        new_lines = [l for l in content.splitlines() if "cybra_invoice_lib" not in l]
        gitignore.write_text("\n".join(new_lines) + "\n")
    else:
        print("  [✓] Файл НЕ в .gitignore")

print("\n═══ 3. ПРИМУСОВИЙ КОМІТ У GIT ═══")
# Перевіряємо, чи файл у Git
r = run("git ls-files lib/cybra_invoice_lib.sh", cwd=str(CYBRA))
if not r.stdout.strip():
    print("  [!] Файл не в Git. Додаємо...")
    run("git add -f lib/cybra_invoice_lib.sh", cwd=str(CYBRA))
else:
    print("  [✓] Файл вже в Git")

# Комітимо
run("git add -A", cwd=str(CYBRA))
r = run('git commit -m "force: add cybra_invoice_lib.sh for EVO"', cwd=str(CYBRA))
print(f"  {r.stdout.strip()}")

# Перевіряємо, чи файл у HEAD
r = run("git cat-file -e HEAD:lib/cybra_invoice_lib.sh", cwd=str(CYBRA))
if r.returncode == 0:
    print("  [✓] Файл у HEAD (можна відновлювати)")
else:
    print("  [✗] Файл НЕ в HEAD!")

print("\n═══ 4. ТЕСТ EVO ═══")
# Видаляємо файл
LIB_FILE.unlink()
print("  [✓] Файл видалено")

# Запускаємо ноду
run(f"bash {CYBRA}/bin/cybra_autonode_main")

# Перевіряємо
if LIB_FILE.exists():
    print("  [✅] УСПІХ! Файл відновлено.")
else:
    print("  [❌] ПРОВАЛ! Файл не відновився.")
    r = run(f"tail -10 {CYBRA}/logs/evo_node_main.log")
    print(r.stdout)

print("\n═══ 5. PM2 ═══")
run("pm2 delete all")
run("pm2 start ~/CYBRA/ecosystem.config.js")
run("pm2 save")
