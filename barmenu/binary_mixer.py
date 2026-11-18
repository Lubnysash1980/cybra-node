#!/usr/bin/env python3
import sys, os, tarfile, hashlib, json
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
SNAP = ROOT / "barmenu" / "snapshots"

def sh(b):
    return hashlib.sha256(b).hexdigest()

def read_snap(path):
    out = {}
    with tarfile.open(path, "r:gz") as t:
        for m in t.getmembers():
            if m.isfile():
                out[m.name] = t.extractfile(m).read()
    return out

def cmd_list():
    for f in sorted(SNAP.glob("*.tar.gz")):
        print(f"{f.name:50s} {f.stat().st_size//1024} KB  sha={sh(f.read_bytes())[:16]}")

def cmd_diff(a, b):
    A = read_snap(SNAP / a); B = read_snap(SNAP / b)
    keys = set(A) | set(B)
    diffs = []
    for k in sorted(keys):
        if A.get(k) != B.get(k):
            diffs.append({
                "file": k,
                "only_in": "A" if k in A and k not in B else ("B" if k in B and k not in A else "both_diff"),
                "a_sha": sh(A[k])[:16] if k in A else None,
                "b_sha": sh(B[k])[:16] if k in B else None,
            })
    out = SNAP / f"diff_{a}__vs__{b}.json"
    out.write_text(json.dumps(diffs, indent=2))
    print(f"📊 Diff: {len(diffs)} файлів різняться → {out.name}")
    for d in diffs[:20]:
        print(f"  {d['only_in']:10s} {d['file']}")

def cmd_merge(out_name, *snaps):
    # Робимо "мікс": беремо послідовно, пізніші перекривають
    merged = {}
    for s in snaps:
        merged.update(read_snap(SNAP / s))
    out = SNAP / out_name
    with tarfile.open(out, "w:gz") as t:
        for path, data in merged.items():
            tmp = SNAP / f".tmp_{sh(path.encode())[:8]}"
            tmp.write_bytes(data)
            t.add(tmp, arcname=path)
            tmp.unlink()
    print(f"✅ Mixed: {out.name}  ({len(merged)} файлів, sha={sh(out.read_bytes())[:16]})")

def cmd_apply(patch_name):
    # "Apply" — просто розпаковує mix у робочу папку
    p = SNAP / patch_name
    with tarfile.open(p, "r:gz") as t:
        t.extractall(ROOT)
    print(f"✅ Applied: {patch_name} → {ROOT}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: binary_mixer.py list|diff A B|merge OUT A B [C...]|apply PATCH")
        sys.exit(1)
    c = sys.argv[1]
    if c == "list": cmd_list()
    elif c == "diff": cmd_diff(sys.argv[2], sys.argv[3])
    elif c == "merge": cmd_merge(sys.argv[2], *sys.argv[3:])
    elif c == "apply": cmd_apply(sys.argv[2])
    else: print("Unknown command")
