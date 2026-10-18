#!/data/data/com.termux/files/usr/bin/bash
# install_parliament_priority.sh — Один скрипт, все ставить

set -e
CYBRA="$HOME/CYBRA"
PC="$CYBRA/parliament_core"
mkdir -p "$PC"
mkdir -p "$CYBRA/logs"

echo "═══ 1. СТВОРЕННЯ PRIORITY MANAGER (МОЗОК ПАРЛАМЕНТУ) ═══"

cat > "$PC/priority_manager.py" <<'PYFILE'
#!/usr/bin/env python3
"""Parliament Priority Manager — resolves conflicts, picks winners"""
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
        with open(LOG, "a") as f:
            f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")
    except: pass

ACTION_KEYWORDS = {
    "invoice_create": ["створити invoice"],
    "invoice_show": ["показати invoice"],
    "invoice_sign": ["підписати invoice"],
    "invoice_finalize": ["фіналізувати"],
    "invoice_add": ["додати позицію"],
    "backup": ["backup", "бекап"],
    "qr": ["qr-код", "qr "],
    "ai": ["ai ", "штучний", "питання"],
    "contract_create": ["створити контракт"],
    "contract_list": ["список контракт"],
    "contract_status": ["статус контракт"],
    "rates": ["курс"],
    "metrics": ["metrics", "метрики"],
    "snapshot": ["snapshot", "знімок"],
    "sync": ["sync", "синхроніз"],
    "validate": ["verify", "перевір"],
    "telegram": ["telegram", "tg "],
    "webhook": ["webhook"],
    "dispute": ["спір"],
    "guardian": ["guardian", "особа"],
    "node": ["node "],
    "evo": ["evo"],
    "ai_analyze": ["ai аналіз"],
    "ai_exec": ["executor"],
}

def infer_action(title):
    t = title.lower()
    for act, kws in ACTION_KEYWORDS.items():
        if any(k in t for k in kws):
            return act
    return "general"

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
            if line.startswith("# ") and len(line) < 80:
                title = line[2:].strip()

        if "СТАТУС: EXTENDED" in content: status, base = "extended", 90
        elif "СТАТУС: BASE" in content: status, base = "base", 50
        elif "trap 'log" in content or 'trap "log' in content: status, base = "hardened", 85
        else: status, base = "unknown", 30

        chk = subprocess.run(["bash","-n",str(main)], capture_output=True)
        if chk.returncode != 0: status, base = "broken", 0
        if size < 200: base = max(0, base - 30)

        mods.append({
            "name": d.name, "title": title,
            "action": infer_action(title),
            "status": status, "base_score": base,
            "size": size, "path": str(main),
        })
    return mods

def compute_score(m):
    s = m["base_score"]
    sz = m["size"]
    if sz > 1000: s += 10
    if sz > 5000: s += 5
    if sz < 100: s -= 20
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
        group.sort(key=lambda x: -x["score"])
        w = group[0]; losers = group[1:]
        resolved[act] = {
            "winner": w["name"], "winner_path": w["path"],
            "winner_score": w["score"], "winner_title": w["title"],
            "standby": [{"name": l["name"], "score": l["score"], "title": l["title"]} for l in losers],
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
        "total_modules": len(modules), "unique_actions": len(resolved),
        "conflicts": len(conflicts),
        "modules": modules, "resolved": resolved, "conflicts_detail": conflicts,
    }
    REGISTRY.write_text(json.dumps(data, indent=2, ensure_ascii=False))

def do_scan():
    log("=== SCAN ===")
    m = scan_modules(); r, c = resolve(m); save(m, r, c)
    log(f"Modules={len(m)}, Actions={len(r)}, Conflicts={len(c)}")
    return m, r, c

def cmd_scan():
    m, r, c = do_scan()
    print(f"✅ Modules: {len(m)}")
    print(f"   Actions: {len(r)}")
    print(f"   Conflicts: {len(c)}")
    return 0

def cmd_show():
    if not REGISTRY.exists(): print("Run 'scan' first"); return 1
    d = json.loads(REGISTRY.read_text())
    print("=" * 60)
    print("  PARLIAMENT REGISTRY")
    print("=" * 60)
    print(f"  Modules: {d.get('total_modules',0)}")
    print(f"  Actions: {d.get('unique_actions',0)}")
    print(f"  Conflicts: {d.get('conflicts',0)}")
    print("-" * 60)
    for act, info in d.get("resolved", {}).items():
        mark = "⚔️ " if info["total"] > 1 else "✅"
        print(f"  {mark} {act}")
        print(f"     WINNER: {info['winner']} (score={info['winner_score']})")
    return 0

def cmd_conflicts():
    if not REGISTRY.exists(): print("Run 'scan' first"); return 1
    d = json.loads(REGISTRY.read_text())
    cs = d.get("conflicts_detail", [])
    if not cs: print("✅ No conflicts"); return 0
    print(f"═══ {len(cs)} CONFLICTS ═══")
    for c in cs:
        print(f"\n⚔️  {c['action']}")
        print(f"   WINNER: {c['winner']} ({c['winner_score']})")
        for o in c["others"]:
            print(f"   STANDBY: {o['name']} ({o['score']})")
    return 0

def cmd_suggest():
    if not REGISTRY.exists(): print("Run 'scan' first"); return 1
    d = json.loads(REGISTRY.read_text())
    low = [m for m in d.get("modules", []) if m.get("score", 0) < 50]
    if not low: print("✅ All modules >= 50"); return 0
    print(f"═══ IT SUGGESTIONS ({len(low)}) ═══")
    for m in low[:20]:
        print(f"🔧 {m['name']} ({m['title']})")
        print(f"   Score={m.get('score',0)} Status={m['status']} Size={m['size']}b")
        if m["status"] == "base": print(f"   💡 extend")
        elif m["size"] < 200: print(f"   💡 stub")
    return 0

def cmd_daemon():
    log("=== DAEMON START ===")
    while True:
        try: do_scan()
        except Exception as e: log(f"ERROR: {e}")
        time.sleep(60)

if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else "show"
    if c == "scan": sys.exit(cmd_scan())
    elif c == "show": sys.exit(cmd_show())
    elif c == "conflicts": sys.exit(cmd_conflicts())
    elif c == "suggest": sys.exit(cmd_suggest())
    elif c == "daemon": cmd_daemon()
    else: sys.exit(1)
PYFILE

chmod +x "$PC/priority_manager.py"
echo "  [✓] priority_manager.py"

echo ""
echo "═══ 2. СУБМЕНЮ ПАРЛАМЕНТУ ═══"

cat > "$PC/menu.sh" <<'MENUFILE'
#!/data/data/com.termux/files/usr/bin/bash
PM="$HOME/CYBRA/parliament_core/priority_manager.py"
clear
echo "════════════════════════════════════════════"
echo "  CYBER PARLIAMENT — PRIORITY MANAGER"
echo "════════════════════════════════════════════"
echo ""
echo "  [1] Show registry (winners per action)"
echo "  [2] Show conflicts"
echo "  [3] IT suggestions"
echo "  [4] Force scan"
echo "  [0] Back"
echo ""
read -p "Choice: " c
case "$c" in
    1) python3 "$PM" show; read -r _ ;;
    2) python3 "$PM" conflicts; read -r _ ;;
    3) python3 "$PM" suggest; read -r _ ;;
    4) python3 "$PM" scan; read -r _ ;;
esac
MENUFILE

chmod +x "$PC/menu.sh"
echo "  [✓] parliament_core/menu.sh"

echo ""
echo "═══ 3. ПАТЧ МЕНЮ (item 121 -> parliament_core) ═══"
MENU="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
if [ -f "$MENU" ]; then
    cp "$MENU" "$MENU.bak.$(date +%s)"
    python3 - <<'PYPATCH'
import re
from pathlib import Path
menu = Path.home() / "CYBRA/modules/module_19_contract_tui_menu/bin/cybra_menu.sh"
text = menu.read_text()
pattern = re.compile(r'^\s*121\)\s+.*?;;', re.MULTILINE)
new = pattern.sub('        121) bash "$HOME/CYBRA/parliament_core/menu.sh" ;;', text)
if new != text:
    menu.write_text(new)
    print("  [✓] item 121 -> parliament_core")
else:
    print("  [!] not patched")
PYPATCH
fi

echo ""
echo "═══ 4. PM2 (додаємо priority daemon) ═══"

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
    }
  ]
};
ECOEOF

echo "  [✓] ecosystem.config.js"

pm2 delete all 2>/dev/null
pm2 start "$CYBRA/ecosystem.config.js"
pm2 save 2>/dev/null

echo ""
echo "═══ 5. ПОЧАТКОВИЙ СКАН ═══"
python3 "$PC/priority_manager.py" scan

echo ""
echo "════════════════════════════════════════════"
echo "  ✅ PARLIAMENT PRIORITY ACTIVE"
echo "════════════════════════════════════════════"
echo ""
echo "  Menu: [121] -> Parliament Priority submenu"
echo "  PM2:  cybra-parliament-priority (daemon 60s)"
echo ""
echo "  Commands:"
echo "    python3 $PC/priority_manager.py show"
echo "    python3 $PC/priority_manager.py conflicts"
echo "    python3 $PC/priority_manager.py suggest"
