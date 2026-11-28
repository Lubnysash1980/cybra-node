#!/usr/bin/env python3
"""Hash Ecosystem — 5 шарів хешів.
  1. Cascade snapshots
  2. Contracts (.sig)
  3. Health + 100% gate
  4. Parliament (proposals/votes)
  5. Combined master hash
"""
import hashlib, json, os, sys, time
from pathlib import Path

H = Path.home() / "CYBRA"
M = H / "modules"
SRC = Path.home() / ".cybra_src"
D = Path(__file__).resolve().parent

def _now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def layer_cascade():
    """Шар 1: каскад snapshot."""
    try:
        sys.path.insert(0, str(M/"module_401_cascade_verify"))
        import verify
        h, _ = verify.cascade_hash()
        return h
    except Exception: return "0"*64

def layer_contracts():
    """Шар 2: контракти (C-INV + .sig)."""
    E = M / "module_19_contract_tui_menu/evidence"
    if not E.exists(): return hashlib.sha256(b"empty").hexdigest()
    h = hashlib.sha256()
    for f in sorted(E.glob("C-INV-*")):
        try:
            h.update(f.name.encode())
            h.update(f.read_bytes())
        except Exception: pass
    return h.hexdigest()

def layer_health():
    """Шар 3: health + 100% gate."""
    parts = {}
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import health
        h = health.health_all()
        parts["health"] = h.get("overall", 0)
    except Exception: parts["health"] = 0
    try:
        sys.path.insert(0, str(M/"module_399_gate"))
        import gate
        ok, s = gate.is_100()
        parts["gate"] = ok
    except Exception: parts["gate"] = False
    try:
        import completion
        parts["completion"] = completion.completion_score().get("overall", 0)
    except Exception: parts["completion"] = 0
    return hashlib.sha256(json.dumps(parts, sort_keys=True).encode()).hexdigest(), parts

def layer_parliament():
    """Шар 4: парламент (proposals/votes/audit)."""
    try:
        sys.path.insert(0, str(M/"module_121_parlament"))
        import parliament as P
        r = P.verify_chain()
        return hashlib.sha256(json.dumps(r, sort_keys=True).encode()).hexdigest(), r
    except Exception: return "0"*64, {}

def layers():
    """Всі 5 шарів."""
    l1 = layer_cascade()
    l2 = layer_contracts()
    l3, h_info = layer_health()
    l4, p_info = layer_parliament()
    combined = {
        "cascade": l1, "contracts": l2, "health_gate": l3, "parliament": l4,
        "at": _now(),
    }
    master = hashlib.sha256(json.dumps(combined, sort_keys=True).encode()).hexdigest()
    return {
        "at": _now(),
        "layers": {
            "1_cascade": l1, "2_contracts": l2, "3_health_gate": l3, "4_parliament": l4,
        },
        "master": master,
        "health": h_info,
        "parliament": p_info,
    }


# ─── Git Hash autosave: rolling 100-entry integrity ledger ───
HASH_CONFIG = D / "state" / "git_hash_config.json"
HASH_STORE = D / "state" / "git_hash_100.json"

def _canonical_hash(value):
    raw = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    return hashlib.sha256(raw).hexdigest()

def load_hash_config():
    defaults = {"enabled": True, "limit": 100, "store": str(HASH_STORE)}
    try:
        cfg = json.loads(HASH_CONFIG.read_text(encoding="utf-8"))
        if not isinstance(cfg, dict): raise ValueError("config must be an object")
        defaults.update(cfg)
    except FileNotFoundError:
        pass
    limit = defaults.get("limit")
    if not isinstance(limit, int) or isinstance(limit, bool) or limit != 100:
        raise ValueError("hash history limit must be exactly 100")
    if defaults.get("store") != str(HASH_STORE):
        raise ValueError("custom hash store path is not allowed")
    return defaults

def autosave_hash_record(result):
    """Append one integrity record; keep exactly the newest maximum of 100."""
    cfg = load_hash_config()
    if not cfg.get("enabled", True):
        return None
    HASH_STORE.parent.mkdir(parents=True, exist_ok=True)
    try:
        state = json.loads(HASH_STORE.read_text(encoding="utf-8"))
        if not isinstance(state, dict) or not isinstance(state.get("records"), list):
            raise ValueError("invalid hash ledger structure")
    except FileNotFoundError:
        state = {"schema": 1, "records": []}
    records = state["records"]
    record = {
        "sequence": (records[-1].get("sequence", 0) + 1) if records else 1,
        "at": result["at"],
        "layers": result["layers"],
        "master_hash": result["master"],
    }
    records.append(record)
    records = records[-100:]
    # One root hash commits to the ordered list of all retained master hashes.
    root_payload = [item["master_hash"] for item in records]
    state = {
        "schema": 1,
        "limit": 100,
        "count": len(records),
        "records": records,
        "root_hash": _canonical_hash(root_payload),
        "updated_at": result["at"],
        "note": "Hashes prove integrity; original source data must be retained separately."
    }
    tmp = HASH_STORE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(state, sort_keys=True, indent=2, ensure_ascii=False) + "\\n", encoding="utf-8")
    os.replace(tmp, HASH_STORE)
    return state

\nif __name__ == "__main__":
    import sys
    G='\033[32m'; R='\033[31m'; B='\033[36m'; BOLD='\033[1m'; D='\033[2m'; N='\033[0m'
    cmd = sys.argv[1] if len(sys.argv) > 1 else "show"
    if cmd in ("show",""):
        r = layers()
        print(f"\n  {B}{BOLD}═══ HASH ECOSYSTEM ═══{N}\n")
        print(f"  {B}Шар 1 · Cascade:{N}     {r['layers']['1_cascade'][:32]}…")
        print(f"  {B}Шар 2 · Contracts:{N}   {r['layers']['2_contracts'][:32]}…")
        print(f"  {B}Шар 3 · Health+Gate:{N} {r['layers']['3_health_gate'][:32]}…")
        print(f"  {B}Шар 4 · Parliament:{N}  {r['layers']['4_parliament'][:32]}…")
        print(f"\n  {B}{BOLD}MASTER HASH:{N}")
        print(f"  {G}{r['master']}{N}\n")
    elif cmd == "json":
        r = layers()\n        autosave_hash_record(r)\n        print(json.dumps(r, indent=2, ensure_ascii=False))
    elif cmd == "hash":
        r = layers()\n        autosave_hash_record(r)\n        print(r["master"])\n    elif cmd == "history":\n        if HASH_STORE.exists(): print(HASH_STORE.read_text(encoding="utf-8"))\n        else: print("No saved hashes yet")
