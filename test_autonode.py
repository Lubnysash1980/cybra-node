#!/usr/bin/env python3
import os, sys, subprocess, shutil, time
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LIB = CYBRA / "lib" / "cybra_invoice_lib.sh"
LOG = CYBRA / "logs" / "evo_node.log"
NODE = CYBRA / "bin" / "cybra_autonode"

G, R, Y, C, Z = "\033[92m", "\033[91m", "\033[93m", "\033[96m", "\033[0m"
def ok(m): print(f"  {G}[✓]{Z} {m}")
def bad(m): print(f"  {R}[✗]{Z} {m}")
def info(m): print(f"  {C}[i]{Z} {m}")
def hdr(m): print(f"\n{C}═══ {m} ═══{Z}")

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

hdr("1. ПЕРЕВІРКА ПЕРЕДУМОВ")
if not NODE.exists():
    bad(f"Ноду не знайдено: {NODE}")
    sys.exit(1)
ok(f"Нода існує: {NODE}")

if not LIB.exists():
    warn_msg = "Файл cybra_invoice_lib.sh ВІДСУТНІЙ (це добре для тесту)"
    print(f"  {Y}[!]{Z} {warn_msg}")
else:
    ok("Файл cybra_invoice_lib.sh на місці")

# Перевірка Git
r = run(f"cd {CYBRA} && git status --porcelain")
if "cybra_invoice_lib.sh" in r.stdout:
    bad("Файл cybra_invoice_lib.sh має незакомічені зміни! EVO не зможе його відновити.")
    sys.exit(1)
ok("Git готовий")

hdr("2. ТЕСТ 1: НОРМАЛЬНИЙ СТАН (все на місці)")
# 1. Створюємо файл, якщо його немає (щоб почати з чистого аркуша)
if not LIB.exists():
    info("Відновлюємо файл з Git...")
    run(f"cd {CYBRA} && git checkout HEAD -- lib/cybra_invoice_lib.sh")
    
r = run(f"cd {CYBRA} && ~/CYBRA/bin/cybra_autonode")
if "EVO: 100% — система стабільна" in r.stdout or "100%" in r.stdout:
    ok("Нода каже: 100% — система стабільна")
else:
    # Перевіряємо логи
    r_log = run(f"tail -5 {LOG}")
    if "100%" in r_log.stdout:
        ok("Нода каже: 100% (знайдено в логах)")
    else:
        bad("Нода не каже 100%")
        print(r_log.stdout)

hdr("3. ТЕСТ 2: ІМІТАЦІЯ ЗЛАМУ (видаляємо файл)")
if LIB.exists():
    LIB.unlink()
    ok("Файл cybra_invoice_lib.sh ВИДАЛЕНО")
else:
    info("Файл вже відсутній")

# Очищуємо логи перед тестом
run(f"echo '' > {LOG}")

hdr("4. ЗАПУСК НОДИ (вона має відновити файл)")
r = run(f"cd {CYBRA} && ~/CYBRA/bin/cybra_autonode")
time.sleep(1)

# Перевіряємо, чи файл з'явився
if LIB.exists():
    ok("Файл ВІДНОВЛЕНО автоматично!")
else:
    bad("Файл НЕ відновлено. Перевіряємо логи...")
    print(run(f"cat {LOG}").stdout)

hdr("5. АНАЛІЗ ЛОГІВ")
log_content = run(f"cat {LOG}").stdout
print(log_content)

if "git reset --hard" in log_content or "Відкат успішний" in log_content:
    ok("В логах є сліди відкату (git reset)")
else:
    info("В логах немає слідів відкату")

if "100%" in log_content:
    ok("В логах є 100% стан")
