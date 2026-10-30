#!/usr/bin/env python3
"""CYBRA License module — DUAL + CREATION ledgers.

Видає, перевіряє, веде облік ліцензій. Підпис HMAC парламентським токеном.
1%+1%+1% фіксується у ledger (не стягується автоматично — тільки облік).

Команди:
  issue <holder> <type> [--contracts N]   видати ліцензію
  verify <license-id>                     перевірити цілісність
  show <license-id>                       показати ліцензію
  ledger [dual|creation|all]              реєстр
  revoke <license-id> <reason>            відкликати (записує в ledger)
"""
import os, sys, json, time, hmac, hashlib, secrets
from pathlib import Path
from datetime import datetime, timezone

HOME     = Path(os.path.expanduser("~"))
CYBRA    = HOME / "CYBRA"
LIC_DIR  = CYBRA / "state" / "licenses"
DUAL     = LIC_DIR / "dual.jsonl"
CREATION = LIC_DIR / "creation.jsonl"
REVOKED  = LIC_DIR / "revoked.jsonl"
TOKEN_F  = HOME / ".pm2" / "ctl" / "parliament.token"
LIC_DIR.mkdir(parents=True, exist_ok=True)

FEE_SPLIT = {"platform_pct": 1.0, "creator_pct": 1.0, "network_pct": 1.0}  # 1%+1%+1%

def token():
    if not TOKEN_F.exists(): return b""
    return TOKEN_F.read_text().strip().encode() or b""

def canon(o): return json.dumps(o, sort_keys=True, separators=(",", ":")).encode()
def hmac_hex(b): return hmac.new(token(), b, hashlib.sha256).hexdigest() if token() else "unsigned"
def sha256(b): return hashlib.sha256(b).hexdigest()

def now_iso(): return datetime.now(timezone.utc).isoformat()

def append_jsonl(path, obj):
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(obj, sort_keys=True) + "\n")

def iter_jsonl(path):
    if not path.exists(): return
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line: continue
        try: yield json.loads(line)
        except Exception: continue

def find_license(lid):
    for f in (DUAL, CREATION):
        for rec in iter_jsonl(f):
            if rec.get("license_id") == lid:
                return rec, f.name
    return None, None

def issue(holder, ltype, contracts=1):
    if ltype not in ("dual", "creation"):
        print(f"!! невідомий тип: {ltype} (dual|creation)"); sys.exit(1)
    lid = f"lic_{ltype[:3]}_{int(time.time())}_{secrets.token_hex(4)}"
    body = {
        "license_id": lid,
        "type": ltype,
        "holder": holder,
        "issued_at": now_iso(),
        "issued_by": "parliament",
        "contracts": int(contracts),
        "fee_split": FEE_SPLIT,
        "network": "BSC(56)",
        "status": "active",
    }
    sig = hmac_hex(canon(body))
    rec = dict(body); rec["signature"] = sig; rec["sha256"] = sha256(canon(body))
    target = DUAL if ltype == "dual" else CREATION
    append_jsonl(target, rec)
    print(json.dumps(rec, indent=2))
    return rec

def verify(lid):
    rec, where = find_license(lid)
    if not rec: print(f"NOT_FOUND: {lid}"); sys.exit(2)
    body = {k: rec[k] for k in rec if k not in ("signature", "sha256")}
    ok_sig  = (rec.get("signature") == hmac_hex(canon(body))) or rec.get("signature") == "unsigned"
    ok_hash = rec.get("sha256") == sha256(canon(body))
    revoked = any(r.get("license_id")==lid for r in iter_jsonl(REVOKED))
    print(json.dumps({
        "license_id": lid, "where": where,
        "signature_ok": ok_sig, "sha256_ok": ok_hash,
        "revoked": revoked, "status": "ok" if (ok_sig and ok_hash and not revoked) else "invalid"
    }, indent=2))
    sys.exit(0 if (ok_sig and ok_hash and not revoked) else 3)

def show(lid):
    rec, where = find_license(lid)
    if not rec: print(f"NOT_FOUND: {lid}"); sys.exit(2)
    print(f"# source: {where}")
    print(json.dumps(rec, indent=2))

def ledger(which="all"):
    out = {"dual": [], "creation": [], "revoked": []}
    if which in ("dual","all"):
        out["dual"] = list(iter_jsonl(DUAL))
    if which in ("creation","all"):
        out["creation"] = list(iter_jsonl(CREATION))
    out["revoked"] = list(iter_jsonl(REVOKED))
    print(json.dumps(out, indent=2))

def revoke(lid, reason):
    rec, _ = find_license(lid)
    if not rec: print(f"NOT_FOUND: {lid}"); sys.exit(2)
    entry = {"license_id": lid, "revoked_at": now_iso(), "reason": reason,
             "by": "parliament", "sig": hmac_hex(canon({"id":lid,"r":reason}))}
    append_jsonl(REVOKED, entry)
    print(json.dumps(entry, indent=2))

def main(argv):
    if not argv:
        print(__doc__); return 0
    cmd = argv[0]
    try:
        if cmd == "issue" and len(argv) >= 3:
            contracts = 1
            if "--contracts" in argv:
                i = argv.index("--contracts"); contracts = int(argv[i+1])
            issue(argv[1], argv[2], contracts)
        elif cmd == "verify" and len(argv) >= 2: verify(argv[1])
        elif cmd == "show" and len(argv) >= 2: show(argv[1])
        elif cmd == "ledger": ledger(argv[1] if len(argv)>1 else "all")
        elif cmd == "revoke" and len(argv) >= 3: revoke(argv[1], " ".join(argv[2:]))
        else: print(__doc__); return 1
    except KeyboardInterrupt: return 130
    except Exception as e:
        print(f"!! {e}"); return 1
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
