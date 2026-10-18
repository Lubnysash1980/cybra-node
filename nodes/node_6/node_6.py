#!/usr/bin/env python3
import os, sys, json, time, hashlib, base64, subprocess
from pathlib import Path
from datetime import datetime, timezone

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"
NODE_DIR = CYBRA / "nodes/node_6"
KEY_FILE = CYBRA / "nodes/keys/node_6.key"
STATE_FILE = NODE_DIR / "state/state.json"
LOG = NODE_DIR / "logs/node_6.log"

def load_key():
    return KEY_FILE.read_bytes().strip()

def sign(data: str, key: bytes) -> str:
    import hmac
    return hmac.new(key, data.encode(), hashlib.sha256).hexdigest()

def encrypt(data: str, key: bytes) -> str:
    # Просте XOR-шифрування з ключем (для демо; у реальності - AES)
    kb = key * (len(data) // len(key) + 1)
    enc = bytes([a ^ b for a, b in zip(data.encode(), kb[:len(data)])])
    return base64.b64encode(enc).decode()

def log(msg):
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with open(LOG, "a") as f:
        f.write(f"[{datetime.now(timezone.utc).isoformat()}] {msg}\n")

def run(cmd):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True)

def get_state():
    if STATE_FILE.exists():
        try: return json.loads(STATE_FILE.read_text())
        except: pass
    return {"cycles": 0, "signed_actions": 0, "role": "brain"}

def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))

def node_logic(state, key):
    """Основна логіка ноди (різна для кожної)"""
    
    # Brain: збирає загальну статистику
    state["modules"] = len(list((CYBRA / "modules").glob("module_*")))
    state["logs"] = len(list((CYBRA / "logs").glob("*.log")))

    return state

def daemon():
    log(f"Node 6 (brain) starting...")
    key = load_key()
    state = get_state()
    
    while True:
        try:
            state["cycles"] += 1
            
            # Виконуємо логіку
            state = node_logic(state, key)
            
            # Підписуємо результат
            payload = json.dumps({"node": 6, "cycle": state["cycles"], "role": "brain"})
            signature = sign(payload, key)
            state["last_signature"] = signature[:16]
            state["signed_actions"] = state.get("signed_actions", 0) + 1
            
            # Шифруємо стан (щоб ніхто не міг прочитати)
            encrypted = encrypt(json.dumps(state), key)
            (NODE_DIR / "state/encrypted.bin").write_text(encrypted)
            
            save_state(state)
            
        except Exception as e:
            log(f"ERROR: {e}")
        
        time.sleep(60)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "once":
        key = load_key()
        state = get_state()
        state = node_logic(state, key)
        print(json.dumps(state, indent=2))
    else:
        daemon()
