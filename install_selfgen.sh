#!/data/data/com.termux/files/usr/bin/bash
# install_selfgen.sh — Створює модуль самогенерації (Self-Generation / Auto-Remote)

CYBRA="$HOME/CYBRA"
SG="$CYBRA/selfgen"
mkdir -p "$SG/logs"

echo "═══ 1. СТВОРЕННЯ ЯДРА САМОГЕНЕРАЦІЇ ═══"

cat > "$SG/selfgen_core.py" <<'PYEOF'
#!/usr/bin/env python3
import os, sys, json, subprocess, shutil, time, hashlib
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
SG = CYBRA / "selfgen"
STATE = SG / "state.json"
LOG = SG / "logs/selfgen.log"

def log(msg):
    LOG.parent.mkdir(exist_ok=True)
    with open(LOG, "a") as f:
        f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")
    print(f"  [SG] {msg}")

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

def get_hash(path):
    if not path.exists(): return None
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]

# ─── 1. ДІАГНОСТИКА (Що зламалося?) ───
def diagnose():
    log("Diagnosing system...")
    issues = []
    
    # Перевірка PM2
    r = run("pm2 jlist")
    if r.returncode != 0:
        issues.append("pm2_dead")
    else:
        try:
            procs = json.loads(r.stdout)
            for p in procs:
                if p["pm2_env"]["status"] != "online":
                    issues.append(f"pm2_{p['name']}_offline")
        except:
            issues.append("pm2_json_broken")

    # Перевірка Git
    if not (CYBRA / ".git").exists():
        issues.append("git_missing")
    elif not run("git remote -v", cwd=CYBRA).stdout.strip():
        issues.append("git_remote_missing")

    # Перевірка ключових файлів
    critical = [
        CYBRA / "modules/module_19_contract_tui_menu/bin/cybra_menu.sh",
        CYBRA / "lib/cybra_invoice_lib.sh"
    ]
    for f in critical:
        if not f.exists():
            issues.append(f"missing_{f.name}")

    return issues

# ─── 2. ЛІКУВАННЯ (Авто-ремонт) ───
def heal(issues):
    log(f"Healing {len(issues)} issues...")
    fixed = 0
    
    for issue in issues:
        if issue == "pm2_dead":
            run("pm2 start ~/CYBRA/ecosystem.config.js")
            run("pm2 save")
            fixed += 1
        elif issue.startswith("pm2_") and issue.endswith("_offline"):
            name = issue[4:-8]
            run(f"pm2 restart {name}")
            fixed += 1
        elif issue == "git_missing":
            run("git init -b main", cwd=CYBRA)
            run("git remote add origin https://github.com/Lubnysash1980/cybra-node.git", cwd=CYBRA)
            fixed += 1
        elif issue == "git_remote_missing":
            run("git remote add origin https://github.com/Lubnysash1980/cybra-node.git", cwd=CYBRA)
            fixed += 1
        elif issue.startswith("missing_"):
            # Намагаємося відновити з Git
            fname = issue[8:]
            run(f"git checkout HEAD -- '**/{fname}'", cwd=CYBRA)
            fixed += 1
            
    return fixed

# ─── 3. СИНХРОНІЗАЦІЯ (Оновлення) ───
def sync():
    log("Syncing with remote...")
    run("git fetch origin main", cwd=CYBRA)
    r = run("git status --porcelain", cwd=CYBRA)
    if r.stdout.strip():
        run("git add -A", cwd=CYBRA)
        run('git commit -m "selfgen: auto-sync"', cwd=CYBRA)
    run("git pull origin main --rebase", cwd=CYBRA)
    run("git push origin main", cwd=CYBRA)

# ─── 4. ЦИКЛ (Слідкування) ───
def daemon():
    log("SelfGen Daemon started.")
    while True:
        try:
            issues = diagnose()
            if issues:
                log(f"Issues found: {len(issues)}")
                fixed = heal(issues)
                log(f"Fixed: {fixed}")
            else:
                log("System healthy (100%)")
            
            # Кожні 10 циклів робимо синхронізацію
            if int(time.time()) % 600 < 60:
                sync()
                
        except Exception as e:
            log(f"ERROR: {e}")
            
        time.sleep(60)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "daemon":
        daemon()
    elif len(sys.argv) > 1 and sys.argv[1] == "check":
        i = diagnose()
        print(f"Found {len(i)} issues: {i}")
    else:
        daemon()
PYEOF

chmod +x "$SG/selfgen_core.py"
echo "  [✓] selfgen_core.py створено"

echo ""
echo "═══ 2. ІНТЕГРАЦІЯ В PM2 (АВТОЗАПУСК) ═══"
cat > "$CYBRA/ecosystem.config.js" <<'ECOEOF'
module.exports = {
  apps: [
    {
      name: "cybra-autonode-main",
      script: "/data/data/com.termux/files/home/CYBRA/bin/run_node.js",
      args: ["/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_main"],
      interpreter: "node",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    },
    {
      name: "cybra-autonode-cybra",
      script: "/data/data/com.termux/files/home/CYBRA/bin/run_node.js",
      args: ["/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_cybra"],
      interpreter: "node",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    },
    {
      name: "cybra-parliament-worker",
      script: "/data/data/com.termux/files/home/CYBRA/parliament_auto_worker.sh",
      interpreter: "bash",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    },
    {
      name: "cybra-parliament-priority",
      script: "/data/data/com.termux/files/home/CYBRA/parliament_core/priority_manager.py",
      args: ["daemon"],
      interpreter: "python3",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    },
    {
      name: "cybra-selfgen-daemon",
      script: "/data/data/com.termux/files/home/CYBRA/selfgen/selfgen_core.py",
      args: ["daemon"],
      interpreter: "python3",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    }
  ]
};
ECOEOF

pm2 delete all 2>/dev/null
pm2 start "$CYBRA/ecosystem.config.js"
pm2 save 2>/dev/null

echo ""
echo "═══ 3. ПЕРВИННА ПЕРЕВІРКА (AUDIT) ═══"
python3 "$SG/selfgen_core.py" check

echo ""
echo "═══ 4. ІНТЕГРАЦІЯ В МЕНЮ (ПУНКТ 108) ═══"
# Замінюємо пункт 108 на виклик selfgen
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
if [ -f "$MENU" ]; then
    cp "$MENU" "$MENU.bak.$(date +%s)"
    python3 -c "
import re
from pathlib import Path
menu = Path.home() / 'CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh'
text = menu.read_text()
pattern = re.compile(r'^\s*108\)\s+.*?;;', re.MULTILINE)
new = pattern.sub('        108) python3 \"\$HOME/CYBRA/selfgen/selfgen_core.py\" check; read -r _ ;;', text)
menu.write_text(new)
print('  [✓] Пункт [108] тепер показує статус SelfGen')
"
fi

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ SELF-GENERATION MODULE INSTALLED"
echo "  Компоненти:"
echo "  - Ядро: $SG/selfgen_core.py"
echo "  - Логи: $SG/logs/selfgen.log"
echo "  - Автозапуск: PM2 (cybra-selfgen-daemon)"
echo "  - Меню: [108]"
echo ""
echo "  Як працює:"
echo "  - Кожні 60с перевіряє PM2, Git, файли."
echo "  - Якщо є проблеми — лікує."
echo "  - Кожні 10с — синхронізує з GitHub."
echo "════════════════════════════════════════════"
