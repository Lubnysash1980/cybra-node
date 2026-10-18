#!/usr/bin/env python3
import os, sys, json, time, re, subprocess
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
MODS = CYBRA / "modules"
PC = CYBRA / "parliament_core"
REGISTRY = PC / "registry.json"
LOG = CYBRA / "logs/parliament_priority.log"
LOG.parent.mkdir(exist_ok=True)

def log(msg):
    try:
        with open(LOG, "a") as f: f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")
    except: pass

# РОЗУМНИЙ МАПІНГ ДІЙ (більше не буде роздутого 'general')
ACTIONS = {
    "metamask": ["metamask", "web3"],
    "parliament": ["parlament", "парламент"],
    "invoice": ["invoice", "рахунок"],
    "contract": ["контракт", "contract"],
    "backup": ["backup", "бекап"],
    "qr": ["qr"],
    "ai": ["ai", "штучний", "питання"],
    "telegram": ["telegram", "tg"],
    "webhook": ["webhook"],
    "snapshot": ["snapshot", "знімок"],
    "validate": ["verify", "перевір"],
    "system": ["system", "debug", "preflight"],
    "node": ["node"],
    "evo": ["evo"],
    "rates": ["курс", "rate"],
    "metrics": ["metrics", "метрик"],
}

def infer_action(title):
    t = title.lower()
    for act, kws in ACTIONS.items():
        if any(k in t for k in kws): return act
    # Якщо не знайшли - беремо перше слово
    w = re.sub(r'[^a-zа-яіїєґ0-9]', '', t.split()[0]) if t else "unknown"
    return w if w else "general"

def scan_modules():
    mods = []
    for d in MODS.iterdir():
        if not d.is_dir() or not d.name.startswith("module_"): continue
        main = d / "main.sh"
        if not main.exists(): continue
        try:
            content = main.read_text(errors="replace")
            size = main.stat().st_size
        except: continue

        title = d.name
        for line in content.split("\n")[:15]:
            if "МОДУЛЬ" in line and ":" in line:
                title = line.split(":", 1)[1].strip(); break

        if "СТАТУС: EXTENDED" in content: status, base = "extended", 90
        elif "СТАТУС: BASE" in content: status, base = "base", 50
        else: status, base = "unknown", 30

        chk = subprocess.run(["bash","-n",str(main)], capture_output=True)
        if chk.returncode != 0: status, base = "broken", 0
        if size < 200: base = max(0, base - 30)

        mods.append({
            "name": d.name, "title": title, "action": infer_action(title),
            "status": status, "base_score": base, "size": size, "path": str(main),
        })
    return mods

def compute_score(m):
    s = m["base_score"]
    if m["size"] > 1000: s += 10
    if m["size"] > 5000: s += 5
    if m["size"] < 100: s -= 20
    try:
        c = Path(m["path"]).read_text(errors="replace")
        if "trap" in c: s += 5
        if "log()" in c: s += 3
        if "read -r" in c or "read -p" in c: s += 2
    except: pass
    return max(0, min(100, s))

def resolve(modules):
    by_action = {}
    for m in modules:
        m["score"] = compute_score(m)
        by_action.setdefault(m["action"], []).append(m)
    resolved, conflicts = {}, []
    for act, group in by_action.items():
        group.sort(key=lambda x: (-x["score"], x["name"]))
        w = group[0]; losers = group[1:]
        resolved[act] = {
            "winner": w["name"], "winner_path": w["path"], "winner_score": w["score"], "winner_title": w["title"],
            "standby": [{"name": l["name"], "score": l["score"]} for l in losers],
            "total": len(group),
        }
        if len(group) > 1:
            conflicts.append({
                "action": act, "winner": w["name"], "winner_score": w["score"],
                "others": [{"name": l["name"], "score": l["score"]} for l in losers],
            })
    return resolved, conflicts

def save(modules, resolved, conflicts):
    data = {
        "updated": datetime.now(timezone.utc).isoformat(),
        "total_modules": len(modules), "unique_actions": len(resolved), "conflicts": len(conflicts),
        "modules": modules, "resolved": resolved, "conflicts_detail": conflicts,
    }
    REGISTRY.write_text(json.dumps(data, indent=2, ensure_ascii=False))

def cmd_scan():
    m = scan_modules(); r, c = resolve(m); save(m, r, c)
    print(f"✅ Modules: {len(m)} | Actions: {len(r)} | Conflicts: {len(c)}")

def cmd_clean():
    if not REGISTRY.exists(): return print("Run scan first")
    d = json.loads(REGISTRY.read_text())
    deleted = 0
    for act, info in d.get("resolved", {}).items():
        for loser in info.get("standby", []):
            lname = loser["name"]
            # Видаляємо _generated дублікати, якщо є _base
            if "_generated" in lname and (MODS / f"module_{lname.split('_')[1]}_base").exists():
                subprocess.run(["rm", "-rf", str(MODS / lname)])
                deleted += 1
            # Видаляємо _base, якщо є кращий _generated (рідко, але буває)
            elif "_base" in lname and (MODS / f"module_{lname.split('_')[1]}_generated").exists():
                subprocess.run(["rm", "-rf", str(MODS / lname)])
                deleted += 1
    print(f"🧹 Видалено дублікатів: {deleted}")
    cmd_scan() # Пересканувати після очищення

def cmd_suggest():
    if not REGISTRY.exists(): return print("Run scan first")
    d = json.loads(REGISTRY.read_text())
    # Знаходимо найгірші модулі, які ще не EXTENDED
    worst = sorted(
        [m for m in d.get("modules", []) if m.get("status") != "extended"],
        key=lambda x: x.get("score", 0)
    )[:15]
    print("═══ IT ЗАВДАННЯ (ТОП-15 НА АПГРЕЙД) ═══")
    for m in worst:
        print(f"🔧 {m['name']} (score={m['score']}, action={m['action']})")

def cmd_daemon():
    log("=== DAEMON START ===")
    while True:
        try:
            m = scan_modules(); r, c = resolve(m); save(m, r, c)
        except Exception as e: log(f"ERROR: {e}")
        time.sleep(60)

if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else "show"
    if c == "scan": cmd_scan()
    elif c == "clean": cmd_clean()
    elif c == "suggest": cmd_suggest()
    elif c == "show":
        if not REGISTRY.exists(): print("Run 'scan' first")
        else:
            d = json.loads(REGISTRY.read_text())
            print("═══ РЕЗУЛЬТАТИ ПАРЛАМЕНТУ ═══")
            for act, info in d.get("resolved", {}).items():
                print(f"  {act}: WINNER {info['winner']} (score={info['winner_score']})")
    elif c == "daemon": cmd_daemon()
