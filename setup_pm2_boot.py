#!/usr/bin/env python3
import os, subprocess, stat
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
BOOT_DIR = HOME / ".termux" / "boot"
PM2_BIN = "/data/data/com.termux/files/usr/bin/pm2"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. ЗБЕРЕЖЕННЯ ПОТОЧНОГО СТАНУ PM2 ═══")
r = run("pm2 status")
if "online" not in r.stdout:
    print("  [!] Немає онлайн-процесів. Запускаємо ecosystem.config.js...")
    run("pm2 start ~/CYBRA/ecosystem.config.js")
run("pm2 save")
print("  [✓] pm2 save виконано")

print("\n═══ 2. СТВОРЕННЯ BOOT-СКРИПТА ═══")
BOOT_DIR.mkdir(parents=True, exist_ok=True)

boot_script = f'''#!/data/data/com.termux/files/usr/bin/sh
# CYBRA autostart via pm2 (Termux:Boot)

termux-wake-lock
sleep 5

export HOME="/data/data/com.termux/files/home"
export PATH="/data/data/com.termux/files/usr/bin:$PATH"
export PREFIX="/data/data/com.termux/files/usr"

cd "$HOME/CYBRA" || exit 1

# Відновлюємо процеси PM2
{PM2_BIN} resurrect
{PM2_BIN} save
'''

boot_path = BOOT_DIR / "start-cybra.sh"
boot_path.write_text(boot_script)
os.chmod(boot_path, 0o755)
print(f"  [✓] Створено {boot_path}")

print("\n═══ 3. ПЕРЕВІРКА .bashrc (fallback) ═══")
bashrc = HOME / ".bashrc"
marker = "# --- CYBRA pm2 autostart fallback ---"
if bashrc.exists():
    content = bashrc.read_text()
    if marker not in content:
        with open(bashrc, "a") as f:
            f.write(f'\n{marker}\n')
            f.write('if command -v pm2 >/dev/null 2>&1; then\n')
            f.write('    pm2 pid cybra-autonode-main >/dev/null 2>&1 || pm2 resurrect >/dev/null 2>&1\n')
            f.write('fi\n')
        print("  [✓] Додано fallback у .bashrc")
    else:
        print("  [i] fallback вже є в .bashrc")

print("\n═══ 4. ПЕРЕВІРКА ═══")
r = run("pm2 status")
print(r.stdout)

print("\n[✓] ГОТОВО.")
print("Що зроблено:")
print("  1. pm2 save — стан збережено")
print("  2. ~/.termux/boot/start-cybra.sh — автозапуск при старті")
print("  3. .bashrc — fallback, якщо boot не спрацює")
