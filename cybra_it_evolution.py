#!/usr/bin/env python3
import json, time, hashlib, subprocess, sys, os
from pathlib import Path

ROOT = Path.home() / "CYBRA"
AI_INBOX = "cybra:ai:tasks:block_inbox"
AUDIT = "cybra:it_evolution:audit"
REGISTRY = ROOT / "data/cybra_it_evolution/registry/scripts.json"

def sha(x): return hashlib.sha256(x.encode("utf-8")).hexdigest()
def dsha(o): return sha(sha(json.dumps(o, ensure_ascii=False, sort_keys=True)))
def now(): return time.strftime("%Y-%m-%dT%H:%M:%S%z")

def run(cmd, timeout=180):
    try:
        p = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception as e:
        return 1, "", str(e)

def rpush(key, obj): run(["redis-cli", "LPUSH", key, json.dumps(obj, ensure_ascii=False)], 20)
def rlen(key):
    code, out, _ = run(["redis-cli", "LLEN", key], 20)
    return int(out) if code == 0 and out.strip().isdigit() else 0

def exists(p): return (ROOT / p).exists()
def count(pattern): return len(list(ROOT.glob(pattern)))

def load_json(path, default=None):
    p = ROOT / path if isinstance(path, str) else path
    if not p.exists(): return default if default is not None else {}
    try: return json.loads(p.read_text(encoding="utf-8"))
    except Exception: return default if default is not None else {}

def save_json(path, obj):
    p = ROOT / path if isinstance(path, str) else path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")

def ensure_redis():
    code, out, _ = run(["redis-cli", "ping"], 20)
    if code == 0 and out == "PONG": return True
    (ROOT / "runtime/redis").mkdir(parents=True, exist_ok=True)
    run(["redis-server", "--daemonize", "yes", "--bind", "127.0.0.1", "--port", "6379", "--dir", str(ROOT/"runtime/redis"), "--save", "", "--appendonly", "no"], 30)
    time.sleep(1)
    code, out, _ = run(["redis-cli", "ping"], 20)
    return code == 0 and out == "PONG"

def default_registry():
    return {"safe": {}}

def registry():
    if not REGISTRY.exists(): save_json(REGISTRY, default_registry())
    return load_json(REGISTRY, default_registry())

def register_script(name, path, command):
    reg = registry()
    reg.setdefault("safe", {})
    reg["safe"][name] = {"path": path, "cmd": command}
    save_json(REGISTRY, reg)
    print("✅ registered:", name, "->", " ".join(command))

def submit_task(text):
    task = {"topic": "CYBRA IT Task", "payload": {"text": text}, "time": time.time(), "time_iso": now()}
    task["double_sha"] = dsha(task)
    save_json(f"data/cybra_it_evolution/tasks/task_{task['double_sha'][:16]}.json", task)
    rpush(AI_INBOX, task)
    print("✅ IT task submitted. DOUBLE_SHA:", task["double_sha"])

def run_registered(name):
    reg = registry().get("safe", {})
    if name not in reg:
        print("❌ no such safe command:", name)
        return
    item = reg[name]
    if not exists(item["path"]):
        print("❌ missing script:", item["path"])
        return
    code, out, err = run(item["cmd"], 240)
    print("CMD:", " ".join(item["cmd"]))
    print("CODE:", code)
    if out: print(out[-2000:])
    if err: print(err[-1000:])

def report():
    reg = registry()
    print("✅ CYBRA IT Department Report Generated.")
    print("Registered commands:", list(reg.get("safe", {}).keys()))

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd in ["status", "report"]: report()
    elif cmd == "task": submit_task(" ".join(sys.argv[2:]) or "Task")
    elif cmd == "register": register_script(sys.argv[2], sys.argv[3], sys.argv[4:])
    elif cmd == "run": run_registered(sys.argv[2] if len(sys.argv) > 2 else "")
    else: print("Usage: status|task TEXT|register NAME PATH CMD...|run NAME")

if __name__ == "__main__": main()
