#!/usr/bin/env python3
"""BINMIX MIXIN — поступово додає функції в базові модулі.
   Стратегія: 1 функція за 1 цикл, з rc-check + rollback при падінні.
   Ніколи не переписує весь модуль — тільки вставляє між маркерами.
"""
import os, sys, re, json, subprocess, time, shutil
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MAPPING = CYBRA / "state/ai_tasks/mapping.json"
STATE = CYBRA / "state/ai_tasks/mixin_state.json"
LOG = CYBRA / "logs/mixin.log"
BACKUP = CYBRA / "state/mixin_backups"
LOG.parent.mkdir(parents=True, exist_ok=True)
STATE.parent.mkdir(parents=True, exist_ok=True)
BACKUP.mkdir(parents=True, exist_ok=True)

MARKER = "# <<<BINMIX_EXTENSIONS>>>"

# Функції в порядку додавання (1 за цикл)
FUNCTIONS = [
    ("add", r'''  add|create|register)
    if [ $# -lt 1 ]; then echo "usage: $0 add <name> [value]"; exit 1; fi
    VAL="${2:-$(date +%s)}"
    redis-cli hset "$KEY" "$1" "$VAL" >/dev/null || { echo "FAIL"; exit 1; }
    echo "OK: $1 = $VAL"
    ;;'''),
    ("list", r'''  list|status|show)
    N=$(redis-cli hlen "$KEY" 2>/dev/null || echo 0)
    echo "  items: $N"
    if [ "$N" -gt 0 ]; then
      redis-cli hgetall "$KEY" | paste - - | head -20 | sed 's/^/  /'
    fi
    ;;'''),
    ("delete", r'''  delete|remove|rm)
    if [ $# -lt 1 ]; then echo "usage: $0 delete <name>"; exit 1; fi
    redis-cli hdel "$KEY" "$1" >/dev/null || exit 1
    echo "OK: deleted $1"
    ;;'''),
    ("count", r'''  count)
    echo "  count: $(redis-cli hlen "$KEY" 2>/dev/null || echo 0)"
    ;;'''),
    ("info", r'''  info)
    echo "  module: NNN"
    echo "  key:    $KEY"
    echo "  redis:  $(redis-cli ping 2>/dev/null | head -1)"
    ;;'''),
]

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{t}] {m}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

def load_state():
    if STATE.exists():
        try: return json.loads(STATE.read_text())
        except: pass
    return {"items": {}, "cycle": 0}

def save_state(s):
    STATE.write_text(json.dumps(s, indent=2, ensure_ascii=False))

def load_mapping():
    try: return json.loads(MAPPING.read_text())
    except: return None

def backup_main(path):
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    dst = BACKUP / f"{path.parent.name}_{ts}.sh"
    shutil.copy2(path, dst)
    return dst

def has_function(content, fname):
    # перевіряємо чи вже є ця функція в extension block
    ext_match = re.search(rf'{re.escape(MARKER)}(.*?)\n\n  help', content, re.DOTALL)
    if not ext_match:
        return False
    ext = ext_match.group(1)
    # add/list/delete/count/info шукаємо як action pattern
    patterns = {
        "add": r'^\s*add\|create',
        "list": r'^\s*list\|status',
        "delete": r'^\s*delete\|remove',
        "count": r'^\s*count\)',
        "info": r'^\s*info\)',
    }
    return bool(re.search(patterns.get(fname, rf'^\s*{fname}\)'), ext, re.M))

def insert_function(content, func_text):
    """Вставляє func_text ПЕРЕД help|*), після маркера."""
    if MARKER not in content:
        return None
    # розбиваємо на: pre-marker / post-marker
    idx = content.find(MARKER) + len(MARKER)
    pre = content[:idx]
    post = content[idx:]
    # знайти "help|*)" в post
    help_match = re.search(r'\n\s*help\|\*\)', post)
    if not help_match:
        return None
    # вставити перед help
    new_post = post[:help_match.start()] + "\n" + func_text + post[help_match.start():]
    return pre + new_post

def test_module(path):
    """bash -n + list rc=0 + не падає."""
    r = subprocess.run(["bash","-n",str(path)], capture_output=True, timeout=10)
    if r.returncode != 0:
        return False, f"syntax: {r.stderr.decode()[:100]}"
    r = subprocess.run(["bash", str(path), "help"],
                       capture_output=True, timeout=15, input="")
    if r.returncode != 0:
        return False, f"help rc={r.returncode}"
    r = subprocess.run(["bash", str(path), "list"],
                       capture_output=True, timeout=15, input="")
    if r.returncode != 0:
        return False, f"list rc={r.returncode}"
    return True, "ok"

def mixin_one(module_path, func_name, func_text, state, n):
    """Додає 1 функцію → verify → rollback якщо fail."""
    path = Path(module_path)
    if not path.exists(): return False, "missing"

    content = path.read_text()
    if MARKER not in content:
        return False, "no marker"
    if has_function(content, func_name):
        return False, "already"

    backup = backup_main(path)
    new_content = insert_function(content, func_text)
    if not new_content:
        return False, "insert failed"

    path.write_text(new_content)
    ok, detail = test_module(path)

    if not ok:
        log(f"  ❌ {func_name} FAIL ({detail}) → rollback")
        shutil.copy2(backup, path)
        return False, detail

    log(f"  ✅ {func_name} added (mod {n:03d})")
    state["items"].setdefault(str(n), {"added": []})
    state["items"][str(n)]["added"].append(func_name)
    return True, "ok"

def cycle():
    st = load_state()
    st["cycle"] = st.get("cycle", 0) + 1
    log(f"═══ MIXIN CYCLE {st['cycle']} ═══")

    m = load_mapping()
    if not m:
        log("  no mapping"); return

    modules = m.get("modules", {})
    total_added = 0

    for n_str, info in modules.items():
        n = int(n_str)
        target = info.get("target")
        if not target: continue
        path = Path(target)
        if not path.exists(): continue

        content = path.read_text()
        if MARKER not in content: continue  # не base модуль

        item_st = st["items"].get(n_str, {"added": []})
        added = item_st.get("added", [])

        # додаємо наступну функцію (1 за цикл на модуль)
        for fname, ftext in FUNCTIONS:
            if fname in added: continue
            ok, detail = mixin_one(path, fname, ftext, st, n)
            if ok: total_added += 1
            break  # тільки 1 функція за цикл

        if total_added >= 10:  # батч
            break

    save_state(st)
    log(f"  cycle added: {total_added}")

def status():
    st = load_state()
    m = load_mapping()
    print(f"cycle: {st.get('cycle',0)}")
    if m:
        print(f"mapping: {m['summary']}")
    total_funcs = sum(len(v.get("added", [])) for v in st.get("items", {}).values())
    modules_touched = len(st.get("items", {}))
    print(f"modules touched: {modules_touched}")
    print(f"functions added: {total_funcs} / {modules_touched * len(FUNCTIONS)}")
    for n_str, v in list(st.get("items", {}).items())[:5]:
        print(f"  mod {n_str}: {v.get('added', [])}")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "run":
        interval = int(sys.argv[2]) if len(sys.argv) > 2 else 120
        log(f"═══ MIXIN LOOP (interval={interval}s) ═══")
        while True:
            try: cycle()
            except Exception as e: log(f"ERR {e}")
            time.sleep(interval)
    elif cmd == "once": cycle()
    elif cmd == "status": status()
    else: print("usage: run [interval] | once | status")
