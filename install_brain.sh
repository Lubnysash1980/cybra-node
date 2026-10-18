#!/data/data/com.termux/files/usr/bin/bash
# install_brain.sh — Створює "Мозок Системи" (System Brain)

CYBRA="$HOME/CYBRA"
BRAIN="$CYBRA/brain"
mkdir -p "$BRAIN/logs"
mkdir -p "$BRAIN/state"

echo "═══ 1. СТВОРЕННЯ ЯДРА МОЗКУ (BRAIN CORE) ═══"

cat > "$BRAIN/brain_core.py" <<'PYEOF'
#!/usr/bin/env python3
import os, sys, json, subprocess, time, re
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
BRAIN = CYBRA / "brain"
STATE_FILE = BRAIN / "state/brain_state.json"
LOG = BRAIN / "logs/brain.log"

# Шляхи до інших систем
SG = CYBRA / "selfgen/selfgen_core.py"
PM = CYBRA / "parliament_core/priority_manager.py"
PARLAMENT = CYBRA / "modules/module_121_parlament/bin/parliament_hidl_engine.py"

def log(msg):
    LOG.parent.mkdir(exist_ok=True)
    with open(LOG, "a") as f:
        f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")
    print(f"  [BRAIN] {msg}")

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

def load_state():
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text())
    return {"cycles": 0, "last_actions": [], "health": 100}

def save_state(state):
    STATE_FILE.parent.mkdir(exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

# ─── 1. ЗБІР МЕТРИК ───
def collect_metrics():
    m = {"pm2": [], "git": "unknown", "modules": 0, "conflicts": 0, "evo_snapshots": 0}
    
    # PM2
    r = run("pm2 jlist")
    if r.returncode == 0:
        try:
            for p in json.loads(r.stdout):
                m["pm2"].append({"name": p["name"], "status": p["pm2_env"]["status"]})
        except: pass

    # Git
    if (CYBRA / ".git").exists():
        r = run("git remote -v", cwd=CYBRA)
        m["git"] = "ok" if "origin" in r.stdout else "no_remote"
    else:
        m["git"] = "no_git"

    # Модулі та конфлікти (з реєстру Парламенту)
    reg_file = CYBRA / "parliament_core/registry.json"
    if reg_file.exists():
        try:
            reg = json.loads(reg_file.read_text())
            m["modules"] = reg.get("total_modules", 0)
            m["conflicts"] = reg.get("conflicts", 0)
        except: pass

    # Снапшоти EVO
    snaps = list((CYBRA / "hashes/snapshots").glob("snapshot_*.json"))
    m["evo_snapshots"] = len(snaps)

    return m

# ─── 2. АНАЛІЗ ТА РІШЕННЯ ───
def decide(metrics):
    actions = []
    
    # Якщо PM2 не всі online — запустити/перезапустити
    offline = [p["name"] for p in metrics["pm2"] if p["status"] != "online"]
    if offline:
        actions.append({"type": "pm2_restart", "target": offline, "reason": "offline processes"})

    # Якщо Git зламався — відновити
    if metrics["git"] != "ok":
        actions.append({"type": "fix_git", "reason": f"git status: {metrics['git']}"})

    # Якщо конфліктів > 20 — запустити clean
    if metrics["conflicts"] > 20:
        actions.append({"type": "parliament_clean", "reason": f"{metrics['conflicts']} conflicts"})

    # Якщо модулів < 100 — запустити генерацію
    if metrics["modules"] < 100:
        actions.append({"type": "parliament_generate", "reason": "too few modules"})

    # Якщо снапшотів < 3 — зробити новий
    if metrics["evo_snapshots"] < 3:
        actions.append({"type": "evo_snapshot", "reason": "few snapshots"})

    return actions

# ─── 3. ВИКОНАННЯ ДІЙ ───
def execute(actions):
    for a in actions:
        log(f"EXEC: {a['type']} (reason: {a.get('reason', '')})")
        if a["type"] == "pm2_restart":
            for n in a["target"]:
                run(f"pm2 restart {n}")
        elif a["type"] == "fix_git":
            run("git remote remove origin", cwd=CYBRA)
            run("git remote add origin https://github.com/Lubnysash1980/cybra-node.git", cwd=CYBRA)
        elif a["type"] == "parliament_clean":
            run(f"python3 {PM} clean")
        elif a["type"] == "parliament_generate":
            run(f"python3 {PARLAMENT} vote")
        elif a["type"] == "evo_snapshot":
            run("~/.termux/boot/start-cybra.sh 2>/dev/null || true")
            run(f"python3 {SG} check")

# ─── 4. ГОЛОВНИЙ ЦИКЛ ───
def daemon():
    log("Brain started. Monitoring system...")
    state = load_state()
    
    while True:
        state["cycles"] += 1
        
        # Збір метрик
        metrics = collect_metrics()
        
        # Аналіз
        actions = decide(metrics)
        
        # Виконання
        if actions:
            execute(actions)
            state["last_actions"] = actions
        else:
            log(f"Cycle {state['cycles']}: all OK (modules={metrics['modules']}, conflicts={metrics['conflicts']})")
            
        # Збереження стану
        save_state(state)
        
        time.sleep(120)  # Мозок думає кожні 2 хвилини

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "daemon":
        daemon()
    else:
        # Режим одноразового аналізу
        m = collect_metrics()
        print(f"PM2: {len([p for p in m['pm2'] if p['status']=='online'])}/{len(m['pm2'])} online")
        print(f"Git: {m['git']}")
        print(f"Modules: {m['modules']}")
        print(f"Conflicts: {m['conflicts']}")
        print(f"Snapshots: {m['evo_snapshots']}")
        actions = decide(m)
        print(f"Planned actions: {len(actions)}")
        for a in actions:
            print(f"  - {a['type']} ({a.get('reason','')})")
PYEOF

chmod +x "$BRAIN/brain_core.py"
echo "  [✓] brain_core.py створено"

echo ""
echo "═══ 2. СУБМЕНЮ ДЛЯ МОЗКУ ═══"

cat > "$BRAIN/brain_menu.sh" <<'MENUEOF'
#!/data/data/com.termux/files/usr/bin/bash
BRAIN="$HOME/CYBRA/brain/brain_core.py"
clear
echo "════════════════════════════════════════════"
echo "  SYSTEM BRAIN — ЦЕНТРАЛЬНИЙ ОРКЕСТРАТОР"
echo "════════════════════════════════════════════"
echo ""
echo "  [1] Показати поточний стан (Analysis)"
echo "  [2] Показати план дій (What brain wants to do)"
echo "  [3] Запустити аналіз зараз (Force check)"
echo "  [4] Показати логи (останні 20)"
echo "  [0] Назад"
echo ""
read -p "  Вибір: " c
case "$c" in
    1) python3 "$BRAIN" ;;
    2) python3 "$BRAIN" | grep "Planned" -A 20 ;;
    3) python3 "$BRAIN"; read -r _ ;;
    4) tail -20 "$HOME/CYBRA/brain/logs/brain.log"; read -r _ ;;
esac
MENUEOF

chmod +x "$BRAIN/brain_menu.sh"
echo "  [✓] brain_menu.sh"

echo ""
echo "═══ 3. ІНТЕГРАЦІЯ В МЕНЮ (ПУНКТ 109) ═══"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
if [ -f "$MENU" ]; then
    cp "$MENU" "$MENU.bak.$(date +%s)"
    python3 -c "
import re
from pathlib import Path
menu = Path.home() / 'CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh'
text = menu.read_text()
pattern = re.compile(r'^\s*109\)\s+.*?;;', re.MULTILINE)
new = pattern.sub('        109) bash \"\$HOME/CYBRA/brain/brain_menu.sh\" ;;', text)
menu.write_text(new)
print('  [✓] Пункт [109] тепер Brain Menu')
"
fi

echo ""
echo "═══ 4. ДОДАВАННЯ В PM2 ═══"
# Оновлюємо ecosystem.config.js, додаючи мозок
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
    },
    {
      name: "cybra-brain-daemon",
      script: "/data/data/com.termux/files/home/CYBRA/brain/brain_core.py",
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
echo "═══ 5. ПЕРВИННИЙ АНАЛІЗ МОЗКУ ═══"
python3 "$BRAIN/brain_core.py"

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ SYSTEM BRAIN INSTALLED"
echo "════════════════════════════════════════════"
echo ""
echo "  Як працює:"
echo "  - Цикл кожні 2 хвилини (перевірка + лікування)"
echo "  - Перевіряє: PM2, Git, модулі, конфлікти, снапшоти"
echo "  - Автоматично запускає: clean, generate, snapshot, git fix"
echo ""
echo "  Меню: [109] — System Brain"
echo "  Логи: $BRAIN/logs/brain.log"
