#!/usr/bin/env python3
"""CYBRA Hash Ecosystem — ланцюг 100% станів."""
import os, sys, json, time, hmac, hashlib, subprocess
from pathlib import Path
from datetime import datetime, timezone
HOME = Path(os.path.expanduser("~"))
PM2_HOME = Path(os.environ.get("PM2_HOME", HOME / ".pm2"))
CTL = PM2_HOME / "ctl"; HASH = PM2_HOME / "hash-ecosystem"
BLOCKS = HASH / "blocks"; PROOFS = HASH / "proofs"
EVO_DIR = PM2_HOME / "evolution"; TOKEN_F = CTL / "parliament.token"
GENESIS = "0" * 64
for d in (BLOCKS, PROOFS, HASH, EVO_DIR): d.mkdir(parents=True, exist_ok=True)

def token_bytes():
    if not TOKEN_F.exists(): return b""
    try: return TOKEN_F.read_text().strip().encode()
    except Exception: return b""

def canon(o): return json.dumps(o, sort_keys=True, separators=(",", ":")).encode()
def sha256(b): return hashlib.sha256(b).hexdigest()
def hmac256(k, b): return hmac.new(k, b, hashlib.sha256).hexdigest()

def load_chain():
    out = []
    for f in sorted(BLOCKS.glob("block-*.json")):
        try: out.append(json.loads(f.read_text()))
        except Exception: pass
    return out

def last_hash():
    bl = load_chain(); return bl[-1].get("hash", GENESIS) if bl else GENESIS
def block_index(): return len(load_chain())

def collect_state():
    score = {}
    sp = EVO_DIR / "score.json"
    if sp.exists():
        try: score = json.loads(sp.read_text())
        except Exception: pass
    pm2 = {}
    try:
        jl = json.loads(subprocess.check_output(["pm2","jlist"], stderr=subprocess.DEVNULL, timeout=15) or b"[]")
        for a in jl:
            n = a.get("name")
            if n: pm2[n] = {"status": a.get("pm2_env",{}).get("status"), "restarts": a.get("pm2_env",{}).get("restart_time",0)}
    except Exception: pass
    ctrls = {f.stem: True for f in (CTL / "protected").glob("*.json")}
    nid = (CTL / "node-id").read_text().strip() if (CTL/"node-id").exists() else "unknown"
    return {"ts": datetime.now(timezone.utc).isoformat(), "node_id": nid,
            "score_pct": score.get("score_pct",0), "metrics": score.get("metrics",{}),
            "pm2": pm2, "protected_controllers": ctrls, "ram_mb": score.get("ram_mb")}

def seal(reason="manual"):
    st = collect_state(); payload = canon(st); ph = sha256(payload)
    prev = last_hash(); idx = block_index(); t = token_bytes()
    sig = hmac256(t, (prev+"|"+ph).encode()) if t else "unsigned"
    block = {"index": idx, "prev_hash": prev, "payload_hash": ph, "seal_hmac": sig,
             "signed": bool(t), "reason": reason, "node_id": st["node_id"],
             "score_pct": st["score_pct"], "ts": st["ts"], "payload": st}
    block["hash"] = sha256(canon({k: block[k] for k in ("index","prev_hash","payload_hash","seal_hmac","signed","ts")}))
    f = BLOCKS / f"block-{idx:06d}.json"
    tmp = f.with_suffix(".tmp"); tmp.write_text(json.dumps(block, indent=2)); tmp.rename(f)
    # SNAP_HOOK: автоматичний working snapshot після кожного seal
    try:
        import subprocess as _sp
        _sp.run([str(HOME/"bin"/"cybra-snap-on-seal.sh")], timeout=60, check=False,
                stdout=_sp.DEVNULL, stderr=_sp.DEVNULL)
    except Exception: pass

    # snap hook
    try:
        import subprocess as _sp
        _sp.run([str(HOME/"bin"/"snap-auto.sh"), "hash-seal", "--force"],
                timeout=60, check=False, stdout=_sp.DEVNULL, stderr=_sp.DEVNULL)
    except Exception: pass

    (PROOFS / f"proof-{idx:06d}.json").write_text(json.dumps({
        "index": idx, "hash": block["hash"], "prev_hash": prev, "payload_hash": ph,
        "seal_hmac": sig, "signed": bool(t), "ts": block["ts"], "score_pct": st["score_pct"]
    }, indent=2))
    return block

def verify():
    chain = load_chain()
    if not chain: return True, None, 0
    t = token_bytes(); prev = GENESIS
    for i, b in enumerate(chain):
        if b.get("index") != i: return False, i, len(chain)
        if b.get("prev_hash") != prev: return False, i, len(chain)
        if sha256(canon(b.get("payload",{}))) != b.get("payload_hash"): return False, i, len(chain)
        if b.get("signed") and t:
            if hmac256(t, (prev+"|"+b["payload_hash"]).encode()) != b.get("seal_hmac"): return False, i, len(chain)
        recalc = sha256(canon({k: b.get(k) for k in ("index","prev_hash","payload_hash","seal_hmac","signed","ts")}))
        if recalc != b.get("hash"): return False, i, len(chain)
        prev = b["hash"]
    return True, None, len(chain)

def status():
    ok, bad, cnt = verify()
    print(f"blocks    : {cnt}")
    print(f"chain ok  : {ok}" + (f" (first_bad={bad})" if not ok else ""))
    print(f"last_hash : {last_hash()[:24]}...")
    print(f"signed    : {'yes (parliament)' if token_bytes() else 'NO TOKEN'}")
    sp = EVO_DIR / "score.json"
    if sp.exists():
        try: print(f"current   : {json.loads(sp.read_text()).get('score_pct')}%")
        except Exception: pass

def cmd(c, *a):
    if c == "seal":
        b = seal(a[0] if a else "manual")
        print(f"sealed #{b['index']} hash={b['hash'][:16]}... signed={b['signed']}")
    elif c == "verify":
        ok, bad, cnt = verify()
        print(f"{'OK' if ok else 'BROKEN'} blocks={cnt}" + ("" if ok else f" bad_at={bad}"))
        sys.exit(0 if ok else 1)
    elif c == "status": status()
    elif c == "list":
        for b in load_chain()[-20:]:
            print(f"  #{b['index']:04d}  {b['ts'][:19]}  {b['score_pct']}%  {b['hash'][:12]}  sig={'Y' if b['signed'] else 'N'}")
    elif c == "show":
        idx = int(a[0]) if a else -1
        chain = load_chain()
        if not chain: print("(empty)"); return
        b = chain[idx] if idx < 0 else next((x for x in chain if x["index"]==idx), None)
        print(json.dumps(b, indent=2))
    elif c == "genesis":
        if block_index() == 0:
            b = seal("genesis"); print(f"genesis #{b['index']} {b['hash'][:16]}")
        else: print("genesis exists")
    else:
        print("cmds: seal [reason] | verify | status | list | show [idx] | genesis")

if __name__ == "__main__":
    cmd(sys.argv[1] if len(sys.argv) > 1 else "status", *sys.argv[2:])
