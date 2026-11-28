#!/usr/bin/env python3
"""Bounded, non-executable staging buffer for CYBRA diagnostics and artifacts."""
import argparse, hashlib, json, os, shutil, sys, tempfile, time
from pathlib import Path

ROOT = Path(os.environ.get("CYBRA_ROOT", Path.home() / "CYBRA")).expanduser().resolve()
BUFFER = Path(os.environ.get("CYBRA_BUFFER_DIR", ROOT / "state" / "exchange_buffer")).expanduser().resolve()
LIMIT = 65 * 1024 * 1024
CHUNK = 1024 * 1024

def inside_buffer(p):
    return p.resolve().parent == BUFFER.resolve()

def digest(path):
    h=hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda:f.read(CHUNK), b""): h.update(block)
    return h.hexdigest()

def entries():
    BUFFER.mkdir(parents=True, exist_ok=True)
    return sorted(p for p in BUFFER.iterdir() if p.is_file() and not p.is_symlink() and p.name != "manifest.json")

def used():
    return sum(p.stat().st_size for p in entries())

def manifest():
    items=[]
    for p in entries():
        items.append({"name":p.name,"size":p.stat().st_size,"sha256":digest(p)})
    data={"limit_bytes":LIMIT,"used_bytes":sum(x["size"] for x in items),"free_bytes":LIMIT-sum(x["size"] for x in items),"files":items,"updated_utc":time.strftime("%Y-%m-%dT%H:%M:%SZ",time.gmtime())}
    tmp=BUFFER/".manifest.tmp"
    tmp.write_text(json.dumps(data,indent=2)+"\n")
    os.replace(tmp,BUFFER/"manifest.json")
    return data

def safe_name(s):
    name=Path(s).name
    if name != s or name in ("", ".", "..") or name.startswith("."):
        raise ValueError("use a simple filename (no paths or hidden names)")
    return name

def put(src, name=None):
    source=Path(src).expanduser().resolve(strict=True)
    if not source.is_file() or source.is_symlink(): raise ValueError("source must be a regular file")
    target_name=safe_name(name or source.name)
    BUFFER.mkdir(parents=True,exist_ok=True)
    target=BUFFER/target_name
    if target.exists(): raise FileExistsError(f"{target_name} already exists; remove it explicitly first")
    size=source.stat().st_size
    if size > LIMIT: raise ValueError(f"file is {size} bytes; buffer limit is {LIMIT}")
    if used()+size > LIMIT: raise ValueError(f"buffer capacity exceeded: used={used()} incoming={size} limit={LIMIT}")
    fd,tmp=tempfile.mkstemp(prefix=".incoming-",dir=BUFFER)
    os.close(fd)
    try:
        shutil.copyfile(source,tmp)
        if Path(tmp).stat().st_size != size: raise IOError("size changed during copy")
        os.chmod(tmp,0o600)
        os.replace(tmp,target)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
    print(json.dumps({"stored":target.name,"bytes":size,"sha256":digest(target)},indent=2))
    manifest()

def get(name,dest):
    name=safe_name(name); src=BUFFER/name
    if not src.is_file() or src.is_symlink(): raise FileNotFoundError(name)
    out=Path(dest).expanduser()
    if out.exists(): raise FileExistsError(f"destination exists: {out}; refusing overwrite")
    out.parent.mkdir(parents=True,exist_ok=True)
    fd,tmp=tempfile.mkstemp(prefix=".cybra-export-",dir=out.parent); os.close(fd)
    try:
        shutil.copyfile(src,tmp); os.chmod(tmp,0o600); os.replace(tmp,out)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
    print(json.dumps({"exported":str(out),"bytes":out.stat().st_size,"sha256":digest(out)},indent=2))

def main():
    ap=argparse.ArgumentParser(description="CYBRA 65 MiB safe exchange buffer")
    sub=ap.add_subparsers(dest="action",required=True)
    p=sub.add_parser("put"); p.add_argument("source"); p.add_argument("--name")
    p=sub.add_parser("get"); p.add_argument("name"); p.add_argument("destination")
    sub.add_parser("list"); p=sub.add_parser("remove"); p.add_argument("name")
    sub.add_parser("check")
    a=ap.parse_args()
    BUFFER.mkdir(parents=True,exist_ok=True)
    if a.action=="put": put(a.source,a.name)
    elif a.action=="get": get(a.name,a.destination)
    elif a.action=="list": print(json.dumps(manifest(),indent=2))
    elif a.action=="check":
        m=manifest(); ok=m["used_bytes"]<=LIMIT
        print(json.dumps({"ok":ok,"limit_mib":65,"used_mib":round(m["used_bytes"]/1048576,3),"free_mib":round(m["free_bytes"]/1048576,3)},indent=2))
        sys.exit(0 if ok else 2)
    elif a.action=="remove":
        name=safe_name(a.name); target=BUFFER/name
        if not target.is_file() or target.is_symlink(): raise FileNotFoundError(name)
        target.unlink(); print("REMOVED",name); manifest()

if __name__=="__main__":
    try: main()
    except Exception as e:
        print(f"BUFFER_ERROR: {e}",file=sys.stderr); sys.exit(1)
