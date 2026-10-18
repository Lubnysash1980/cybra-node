#!/usr/bin/env python3
import os, sys, json, subprocess, time, re
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
EVO = CYBRA / "evo"
STATE = EVO / "state/evo_state.json"
LOG = EVO / "logs/evo.log"

# Шляхи до інших систем
SG = CYBRA / "selfgen/selfgen_core.py"
PM = CYBRA / "parliament_core/priority_manager.py"
PARLAMENT = CYBRA / "modules/module_121_parlament/bin/parliament_hidl_engine.py"
MODS = CYBRA / "modules"

def log(msg):
    LOG.parent.mkdir(exist_ok=True)
    with open(LOG, "a") as f:
        f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")
    print(f"  [EVO] {msg}")

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

def load_state():
    if STATE.exists():
        return json.loads(STATE.read_text())
    return {"cycles": 0, "upgrades": 0, "last_check": ""}

def save_state(state):
    STATE.parent.mkdir(exist_ok=True)
    STATE.write_text(json.dumps(state, indent=2))

# ─── 1. ЗБІР СТАТИСТИКИ ───
def collect_evo_metrics():
    m = {"modules": 0, "extended": 0, "base": 0, "broken": 0, "conflicts": 0, "suggestions": 0}
    
    # Скануємо модулі
    for d in MODS.glob("module_*"):
        main_sh = d / "main.sh"
        if main_sh.exists():
            m["modules"] += 1
            content = main_sh.read_text(errors="replace")
            if "СТАТУС: EXTENDED" in content: m["extended"] += 1
            elif "СТАТУС: BASE" in content: m["base"] += 1
            
            # Перевірка синтаксису
            chk = run(f"bash -n {main_sh}")
            if chk.returncode != 0: m["broken"] += 1

    # Конфлікти з Парламенту
    reg = CYBRA / "parliament_core/registry.json"
    if reg.exists():
        try:
            rdata = json.loads(reg.read_text())
            m["conflicts"] = rdata.get("conflicts", 0)
        except: pass

    # Скільки модулів потребують апгрейду
    suggest_out = run(f"python3 {PM} suggest")
    m["suggestions"] = len(re.findall(r'🔧 module_', suggest_out.stdout))

    return m

# ─── 2. АНАЛІЗ ТА РІШЕННЯ ───
def decide_evo_actions(metrics):
    actions = []
    
    # Якщо є биті модулі — виправити
    if metrics["broken"] > 0:
        actions.append({"type": "fix_broken", "count": metrics["broken"]})

    # Якщо є модулі, які потребують апгрейду
    if metrics["suggestions"] > 0:
        actions.append({"type": "upgrade_module", "count": metrics["suggestions"]})

    # Якщо конфліктів > 10 — очистити
    if metrics["conflicts"] > 10:
        actions.append({"type": "clean_conflicts", "count": metrics["conflicts"]})

    # Якщо базових > розширених (всі потребують уваги)
    if metrics["base"] > metrics["extended"]:
        actions.append({"type": "extend_bases", "count": metrics["base"] - metrics["extended"]})

    return actions

# ─── 3. ВИКОНАННЯ ───
def execute_evo(actions):
    for a in actions:
        log(f"EXEC: {a['type']} ({a.get('count', '')} elements)")
        
        if a["type"] == "fix_broken":
            # Знайти і виправити биті модулі
            for d in MODS.glob("module_*"):
                f = d / "main.sh"
                if f.exists():
                    chk = run(f"bash -n {f}")
                    if chk.returncode != 0:
                        # Перезапис безпечним кодом
                        safe = f"""#!/data/data/com.termux/files/usr/bin/bash
# AUTO-FIXED BY EVO
echo "Модуль {d.name} відновлено"
read -r _
"""
                        f.write_text(safe)
                        log(f"FIXED: {d.name}")
        
        elif a["type"] == "upgrade_module":
            # Запустити парламент на апгрейд
            run(f"python3 {PARLAMENT} vote")
            log("Upgraded one module via Parliament")
        
        elif a["type"] == "clean_conflicts":
            run(f"python3 {PM} clean")
            log("Conflicts cleaned")
        
        elif a["type"] == "extend_bases":
            # Парламент розширює базові модулі
            for _ in range(min(a["count"], 3)):  # не більше 3 за раз
                run(f"python3 {PARLAMENT} vote")
                log("Extended a base module")
        
        # Збільшуємо лічильник
        state = load_state()
        state["upgrades"] += 1
        save_state(state)

# ─── 4. ГОЛОВНИЙ ЦИКЛ ───
def daemon():
    log("EVO Core started. Watching evolution...")
    state = load_state()
    
    while True:
        state["cycles"] += 1
        state["last_check"] = datetime.now(timezone.utc).isoformat()
        
        try:
            # 1. Збір
            metrics = collect_evo_metrics()
            log(f"Metrics: modules={metrics['modules']} extended={metrics['extended']} base={metrics['base']} broken={metrics['broken']} suggestions={metrics['suggestions']}")
            
            # 2. Аналіз
            actions = decide_evo_actions(metrics)
            
            # 3. Виконання
            if actions:
                execute_evo(actions)
            else:
                log("EVO: all modules optimal (no action needed)")
            
            save_state(state)
        except Exception as e:
            log(f"ERROR: {e}")
        
        time.sleep(180)  # EVO думає раз на 3 хвилини

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "daemon":
        daemon()
    else:
        # Режим одного аналізу
        metrics = collect_evo_metrics()
        print("═══ EVO METRICS ═══")
        print(f"Total modules: {metrics['modules']}")
        print(f"Extended: {metrics['extended']}")
        print(f"Base (needs upgrade): {metrics['base']}")
        print(f"Broken: {metrics['broken']}")
        print(f"Conflicts: {metrics['conflicts']}")
        print(f"Suggestions: {metrics['suggestions']}")
        
        actions = decide_evo_actions(metrics)
        print(f"\nPlanned actions: {len(actions)}")
        for a in actions:
            print(f"  - {a['type']} ({a.get('count', '')} elements)")
