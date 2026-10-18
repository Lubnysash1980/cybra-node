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

def auto_commit():
    r = run("git status --porcelain", cwd=CYBRA)
    if r.stdout.strip():
        run("git add -A", cwd=CYBRA)
        run(f"git commit -m 'selfgen: auto-sync {datetime.now(timezone.utc).isoformat()}'", cwd=CYBRA)
        run("git push origin main", cwd=CYBRA)
        return len(r.stdout.splitlines())
    return 0

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
            
        auto_commit()
        auto_commit()
        time.sleep(30)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "daemon":
        daemon()
    elif len(sys.argv) > 1 and sys.argv[1] == "check":
        i = diagnose()
        print(f"Found {len(i)} issues: {i}")
    else:
        daemon()
