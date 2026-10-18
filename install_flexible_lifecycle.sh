#!/data/data/com.termux/files/usr/bin/bash
# install_flexible_lifecycle.sh — Гнучкий менеджер перевірок

CYBRA="$HOME/CYBRA"
LC="$CYBRA/lifecycle"
mkdir -p "$LC/logs"
mkdir -p "$LC/state"

echo "═══ 1. СТВОРЕННЯ LIFE CYCLE MANAGER ═══"

cat > "$LC/lifecycle_manager.py" <<'PYEOF'
#!/usr/bin/env python3
import os, sys, json, subprocess, time, re
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
LC = CYBRA / "lifecycle"
STATE = LC / "state/lifecycle.json"
LOG = LC / "logs/lifecycle.log"
MODS = CYBRA / "modules"

def log(msg):
    LOG.parent.mkdir(exist_ok=True)
    with open(LOG, "a") as f:
        f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")
    print(f"  [LC] {msg}")

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

def load_state():
    if STATE.exists():
        try: return json.loads(STATE.read_text())
        except: pass
    return {"modules": {}, "last_check": ""}

def save_state(state):
    STATE.parent.mkdir(exist_ok=True)
    state["last_check"] = datetime.now(timezone.utc).isoformat()
    STATE.write_text(json.dumps(state, indent=2, ensure_ascii=False))

# ─── 1. ПЕРЕВІРКА МОДУЛЯ ───
def check_module(mod_path):
    """Перевіряє модуль і повертає статус"""
    if not mod_path.exists():
        return {"status": "missing", "reason": "file not found"}
    
    # Синтаксис
    chk = run(f"bash -n {mod_path}")
    if chk.returncode != 0:
        return {"status": "development", "reason": f"syntax error: {chk.stderr[:100]}"}
    
    # Розмір
    size = mod_path.stat().st_size
    if size < 100:
        return {"status": "development", "reason": "file too small (<100b)"}
    
    # Чи має trap (захист)
    content = mod_path.read_text(errors="replace")
    if "trap" not in content and "log()" not in content:
        return {"status": "development", "reason": "no trap/log protection"}
    
    return {"status": "ready", "reason": "ok", "size": size}

# ─── 2. СКАНУВАННЯ ВСІХ МОДУЛІВ ───
def scan_all():
    log("Scanning all modules...")
    state = load_state()
    results = {"ready": 0, "development": 0, "missing": 0}
    
    for d in MODS.glob("module_*"):
        main_sh = d / "main.sh"
        check = check_module(main_sh)
        
        state["modules"][d.name] = {
            "status": check["status"],
            "reason": check["reason"],
            "size": check.get("size", 0),
            "checked": datetime.now(timezone.utc).isoformat()
        }
        results[check["status"]] += 1
    
    save_state(state)
    log(f"Scan complete: ready={results['ready']}, development={results['development']}, missing={results['missing']}")
    return results

# ─── 3. ПЕРЕВЕДЕННЯ В РОЗРОБКУ ───
def mark_development(module_name, reason):
    state = load_state()
    state["modules"][module_name] = {
        "status": "development",
        "reason": reason,
        "marked": datetime.now(timezone.utc).isoformat()
    }
    save_state(state)
    log(f"DEV: {module_name} → development ({reason})")

# ─── 4. ГОЛОВНИЙ ЦИКЛ ───
def daemon():
    log("Lifecycle daemon started.")
    while True:
        try:
            scan_all()
        except Exception as e:
            log(f"ERROR: {e}")
        time.sleep(300)  # кожні 5 хвилин

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "scan"
    
    if cmd == "scan":
        r = scan_all()
        print(f"Ready: {r['ready']}, Development: {r['development']}, Missing: {r['missing']}")
    elif cmd == "daemon":
        daemon()
    elif cmd == "show":
        state = load_state()
        print(f"═══ LIFECYCLE STATE ═══")
        print(f"Last check: {state['last_check']}")
        for name, info in state["modules"].items():
            icon = "🟢" if info["status"] == "ready" else "🟡" if info["status"] == "development" else "🔴"
            print(f"{icon} {name}: {info['status']} ({info['reason']})")
    elif cmd == "mark":
        if len(sys.argv) > 3:
            mark_development(sys.argv[2], sys.argv[3])
PYEOF

chmod +x "$LC/lifecycle_manager.py"
echo "  [✓] lifecycle_manager.py створено"

echo ""
echo "═══ 2. ІНТЕГРАЦІЯ В МЕНЮ ═══"

cat > "$LC/lifecycle_menu.sh" <<'MENUEOF'
#!/data/data/com.termux/files/usr/bin/bash
LC="$HOME/CYBRA/lifecycle/lifecycle_manager.py"
clear
echo "════════════════════════════════════════════"
echo "  LIFECYCLE MANAGER — ГНУЧКА ПЕРЕВІРКА"
echo "════════════════════════════════════════════"
echo ""
echo "  [1] Показати стан (show)"
echo "  [2] Пересканувати (scan)"
echo "  [3] Перевести в розробку (mark)"
echo "  [0] Назад"
echo ""
read -p "  Вибір: " c
case "$c" in
    1) python3 "$LC" show; read -r _ ;;
    2) python3 "$LC" scan; read -r _ ;;
    3) 
        read -p "Модуль: " M
        read -p "Причина: " R
        python3 "$LC" mark "$M" "$R"
        read -r _ ;;
esac
MENUEOF

chmod +x "$LC/lifecycle_menu.sh"
echo "  [✓] lifecycle_menu.sh"

echo ""
echo "═══ 3. ДОДАВАННЯ В МЕНЮ (ПУНКТ 111) ═══"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
if [ -f "$MENU" ]; then
    cp "$MENU" "$MENU.bak.$(date +%s)"
    python3 -c "
import re
from pathlib import Path
menu = Path.home() / 'CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh'
text = menu.read_text()
pattern = re.compile(r'^\s*111\)\s+.*?;;', re.MULTILINE)
new = pattern.sub('        111) bash \"\$HOME/CYBRA/lifecycle/lifecycle_menu.sh\" ;;', text)
menu.write_text(new)
print('  [✓] Пункт [111] тепер Lifecycle Menu')
"
fi

echo ""
echo "═══ 4. ДОДАВАННЯ В PM2 ═══"
pm2 delete cybra-lifecycle 2>/dev/null
pm2 start "$LC/lifecycle_manager.py" --name cybra-lifecycle --interpreter python3 -- daemon
pm2 save 2>/dev/null

echo ""
echo "═══ 5. ПЕРВИННИЙ СКАН ═══"
python3 "$LC/lifecycle_manager.py" scan

echo ""
echo "═══ 6. ПОКАЗ СТАНУ ═══"
python3 "$LC/lifecycle_manager.py" show | head -20

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ LIFECYCLE MANAGER INSTALLED"
echo "════════════════════════════════════════════"
echo ""
echo "  Як працює:"
echo "  - Кожні 5 хвилин сканує модулі."
echo "  - Якщо модуль: битий синтаксис / замалий / без захисту → 'development'."
echo "  - Якщо все OK → 'ready'."
echo "  - PM2: cybra-lifecycle"
echo "  - Меню: [111]"
