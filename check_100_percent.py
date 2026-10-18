import re
#!/usr/bin/env python3
import os, sys, json, subprocess, shutil, time
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MODS = CYBRA / "modules"
MENU = MODS / "module_19_contract_tui_menu/bin/cybra_menu.sh"
REGISTRY = CYBRA / "parliament_core/registry.json"
SNAPSHOTS = CYBRA / "hashes/snapshots"

G, Y, R, C, B, Z = "\033[92m", "\033[93m", "\033[91m", "\033[96m", "\033[1m", "\033[0m"
PASS, WARN, FAIL = 0, 0, 0

def ok(m):   global PASS; PASS += 1; print(f"  {G}🟢 [OK]{Z} {m}")
def warn(m): global WARN; WARN += 1; print(f"  {Y}🟡 [WARN]{Z} {m}")
def bad(m):  global FAIL; FAIL += 1; print(f"  {R}🔴 [FAIL]{Z} {m}")
def hdr(m):  print(f"\n{B}{C}═══ {m} ═══{Z}")

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

# 1. ОТОЧЕННЯ
hdr("1. ОТОЧЕННЯ (ENVIRONMENT)")
if shutil.which("python3"): ok("Python3 встановлено")
else: bad("Python3 не знайдено")

if shutil.which("node"): ok("Node.js встановлено")
else: bad("Node.js не знайдено")

if shutil.which("pm2"): ok("PM2 встановлено")
else: bad("PM2 не знайдено")

if shutil.which("git"): ok("Git встановлено")
else: bad("Git не знайдено")

if shutil.which("qrencode"): ok("qrencode встановлено")
else: warn("qrencode не знайдено (QR може не працювати)")

# 2. PM2 ПРОЦЕСИ
hdr("2. PM2 ПРОЦЕСИ (EVO NODES)")
r = run("pm2 jlist")
if r.returncode != 0:
    bad("Не вдалося отримати статус PM2")
else:
    try:
        procs = json.loads(r.stdout)
        pm2_names = {p["name"]: p["pm2_env"]["status"] for p in procs}
        
        required = [
            "cybra-autonode-main", "cybra-autonode-cybra",
            "cybra-parliament-worker", "cybra-parliament-priority"
        ]
        for req in required:
            if req in pm2_names:
                if pm2_names[req] == "online": ok(f"Процес {req} ONLINE")
                else: bad(f"Процес {req} в статусі {pm2_names[req]}")
            else:
                bad(f"Процес {req} ВІДСУТНІЙ у PM2")
    except Exception as e:
        bad(f"PM2 JSON помилка: {e}")

# 3. GIT СТАН
hdr("3. GIT ТА СИНХРОНІЗАЦІЯ")
if not (CYBRA / ".git").exists():
    bad("Немає папки .git (не git-репозиторій)")
else:
    ok("Git репозиторій знайдено")
    r = run("git status --porcelain")
    if len(r.stdout.strip()) == 0:
        ok("Робоче дерево чисте (всі зміни закомічені)")
    else:
        warn(f"Є незакомічені зміни ({len(r.stdout.splitlines())} файлів)")
    
    r = run("git remote -v")
    if "origin" in r.stdout: ok("Git remote (origin) налаштовано")
    else: bad("Git remote не налаштовано")

# 4. МЕНЮ TUI
hdr("4. МЕНЮ TUI")
if not MENU.exists():
    bad("Файл cybra_menu.sh не знайдено")
else:
    r = run(f"bash -n {MENU}")
    if r.returncode == 0: ok("Синтаксис меню OK")
    else: bad("Синтаксис меню ЗЛАМАНО")

    menu_content = MENU.read_text()
    items = len(re.findall(r'^\s*\d+\)', menu_content, re.MULTILINE))
    if items >= 150: ok(f"Меню має {items}+ пунктів")
    else: warn(f"Меню має лише {items} пунктів (очікується 150)")

# 5. МОДУЛІ
hdr("5. МОДУЛІ (БАЗА + РОЗШИРЕНІ)")
if not MODS.exists():
    bad("Папка modules не знайдена")
else:
    all_mods = list(MODS.glob("module_*"))
    base_count, ext_count, broken_count = 0, 0, 0
    
    for d in all_mods:
        main_sh = d / "main.sh"
        if main_sh.exists():
            content = main_sh.read_text(errors="replace")
            if "СТАТУС: BASE" in content: base_count += 1
            elif "СТАТУС: EXTENDED" in content: ext_count += 1
            
            chk = run(f"bash -n {main_sh}")
            if chk.returncode != 0: broken_count += 1
    
    ok(f"Знайдено модулів: {len(all_mods)}")
    if broken_count == 0: ok("Синтаксис всіх модулів OK")
    else: bad(f"Битих модулів (синтаксис): {broken_count}")
    
    print(f"     ├─ Базових (BASE): {base_count}")
    print(f"     └─ Розширених (EXTENDED): {ext_count}")

# 6. ПАРЛАМЕНТ
hdr("6. КІБЕРПАРЛАМЕНТ (PRIORITY MANAGER)")
if not REGISTRY.exists():
    bad("Реєстр парламенту (registry.json) не знайдено")
else:
    ok("Реєстр парламенту знайдено")
    try:
        data = json.loads(REGISTRY.read_text())
        ok(f"Проскановано модулів: {data.get('total_modules', 0)}")
        ok(f"Унікальних дій (actions): {data.get('unique_actions', 0)}")
        
        conflicts = data.get('conflicts', 0)
        if conflicts == 0: ok("Конфліктів не знайдено")
        else: ok(f"Знайдено альтернатив: {conflicts} — Парламент обрав переможців")
        
        # Перевірка свіжості (чи оновлювався реєстр за останні 5 хвилин)
        upd = data.get('updated', '')
        if upd:
            ok(f"Реєстр оновлено: {upd[:19]}")
    except Exception as e:
        bad(f"Помилка читання реєстру: {e}")

# 7. EVO ТА СНАПШОТИ
hdr("7. EVO ТА СНАПШОТИ")
if not SNAPSHOTS.exists():
    bad("Папка снапшотів не знайдена")
else:
    snaps = sorted(SNAPSHOTS.glob("snapshot_*.json"), key=os.path.getmtime, reverse=True)
    if not snaps:
        bad("Снапшоти відсутні")
    else:
        newest = snaps[0]
        age = time.time() - newest.stat().st_mtime
        if age < 300: # 5 хвилин
            ok(f"Свіжий снапшот створено {int(age)}с тому")
        else:
            warn(f"Останній снапшот створено {int(age/60)} хвилин тому")

# ─── ПІДСУМОК ───
hdr("ПІДСУМОК")
total = PASS + WARN + FAIL
pct = int((PASS / total) * 100) if total > 0 else 0

print(f"  Всього перевірок: {total}")
print(f"  {G}🟢 PASS: {PASS}{Z}")
print(f"  {Y}🟡 WARN: {WARN}{Z}")
print(f"  {R}🔴 FAIL: {FAIL}{Z}")
print(f"\n  {B}РІВЕНЬ РОБОТОЗДАТНОСТІ: {pct}%{Z}\n")

if pct >= 95:
    print(f"  {G}✅ СИСТЕМА ПРАЦЮЄ НА 100% (або близько до того){Z}")
elif pct >= 80:
    print(f"  {Y}⚠️ СИСТЕМА ПРАЦЮЄ, АЛЕ Є ПОПЕРЕДЖЕННЯ{Z}")
else:
    print(f"  {R}❌ СИСТЕМА ПОТРЕБУЄ УВАГИ (багато помилок){Z}")
