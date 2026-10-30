#!/usr/bin/env python3
"""CYBRA Working Snapshot — повний знімок робочого стану.

Захоплює: PM2 dump, hash-chain tip, конфіги контролерів, файли контролерів,
cron, bashrc, node-id, token hash (НЕ токен!). Кожен файл у маніфесті
має sha256 → verify() ловить будь-яку підміну.
"""
import os, sys, json, time, hashlib, shutil, subprocess, tarfile, io
from pathlib import Path
from datetime import datetime, timezone

HOME     = Path(os.path.expanduser("~"))
PM2_HOME = Path(os.environ.get("PM2_HOME", HOME / ".pm2"))
CTL      = PM2_HOME / "ctl"
SNAP     = PM2_HOME / "snapshots"
BIN      = HOME / "CYBRA" / "bin"
HASH     = PM2_HOME / "hash-ecosystem" / "blocks"
EVO      = PM2_HOME / "evolution"
for d in (SNAP, CTL, BIN): d.mkdir(parents=True, exist_ok=True)

def sha256_file(p):
    try: return hashlib.sha256(Path(p).read_bytes()).hexdigest()
    except Exception: return None

def canon(o): return json.dumps(o, sort_keys=True, separators=(",",":")).encode()

def pm2_jlist():
    try:
        return json.loads(subprocess.check_output(["pm2","jlist"],
            stderr=subprocess.DEVNULL, timeout=15) or b"[]")
    except Exception: return []

def capture():
    sid = "snap-" + datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    out = SNAP / sid
    out.mkdir(parents=True, exist_ok=True)
    manifest = {"id": sid, "ts": datetime.now(timezone.utc).isoformat(),
                "files": {}, "removed": [], "pm2": {}, "hash_tip": None,
                "score": None, "node_id": None}

    # PM2 dump + jlist
    if (PM2_HOME/"dump.pm2").exists():
        shutil.copy2(PM2_HOME/"dump.pm2", out/"dump.pm2")
        manifest["files"]["dump.pm2"] = sha256_file(out/"dump.pm2")
    jl = pm2_jlist()
    (out/"pm2-jlist.json").write_text(json.dumps(jl, indent=2))
    manifest["files"]["pm2-jlist.json"] = sha256_file(out/"pm2-jlist.json")
    manifest["pm2"] = {a.get("name"): a.get("pm2_env",{}).get("status") for a in jl if a.get("name")}

    # hash chain tip
    blocks = sorted(HASH.glob("block-*.json"))
    if blocks:
        tip = json.loads(blocks[-1].read_text())
        manifest["hash_tip"] = {"index": tip["index"], "hash": tip["hash"]}
        shutil.copy2(blocks[-1], out/"hash-tip.json")
        manifest["files"]["hash-tip.json"] = sha256_file(out/"hash-tip.json")

    # score
    sp = EVO/"score.json"
    if sp.exists():
        try: manifest["score"] = json.loads(sp.read_text()).get("score_pct")
        except Exception: pass
        shutil.copy2(sp, out/"score.json")
        manifest["files"]["score.json"] = sha256_file(out/"score.json")

    # node-id + token hash (без токена!)
    if (CTL/"node-id").exists():
        shutil.copy2(CTL/"node-id", out/"node-id")
        manifest["files"]["node-id"] = sha256_file(out/"node-id")
        manifest["node_id"] = (CTL/"node-id").read_text().strip()
    if (CTL/"parliament.token").exists():
        th = sha256_file(CTL/"parliament.token")
        (out/"token.sha256").write_text(th or "")
        manifest["files"]["token.sha256"] = sha256_file(out/"token.sha256")

    # контролери (py/sh)
    cdir = out/"controllers"; cdir.mkdir(exist_ok=True)
    for f in BIN.glob("cybra_*.py"):
        shutil.copy2(f, cdir/f.name)
        manifest["files"][f"controllers/{f.name}"] = sha256_file(cdir/f.name)
    for f in (BIN.glob("cybra_*loop.sh")):
        shutil.copy2(f, cdir/f.name)
        manifest["files"][f"controllers/{f.name}"] = sha256_file(cdir/f.name)
    for f in (HOME/"bin").glob("autopilot-sync.sh"):
        shutil.copy2(f, cdir/f.name)
        manifest["files"][f"controllers/{f.name}"] = sha256_file(cdir/f.name)

    # конфіги
    cfg = out/"conf"; cfg.mkdir(exist_ok=True)
    for name in ("neuro.conf.json","evolution.conf.json","oracle.conf.json","resurrection.conf.json"):
        src = CTL/name
        if src.exists():
            shutil.copy2(src, cfg/name)
            manifest["files"][f"conf/{name}"] = sha256_file(cfg/name)

    # cron + bashrc
    try:
        cron = subprocess.check_output(["crontab","-l"], stderr=subprocess.DEVNULL, timeout=10).decode()
        (out/"crontab.txt").write_text(cron)
        manifest["files"]["crontab.txt"] = sha256_file(out/"crontab.txt")
    except Exception: pass
    if (HOME/".bashrc").exists():
        shutil.copy2(HOME/".bashrc", out/"bashrc")
        manifest["files"]["bashrc"] = sha256_file(out/"bashrc")

    # маніфест
    manifest["sealed"] = hashlib.sha256(canon(manifest)).hexdigest()
    (out/"manifest.json").write_text(json.dumps(manifest, indent=2))

    # tarball (окремо — для переносу)
    tarball = SNAP / f"{sid}.tar.gz"
    with tarfile.open(tarball, "w:gz") as t:
        t.add(out, arcname=sid)
    manifest["tarball"] = tarball.name
    manifest["tarball_sha256"] = sha256_file(tarball)

    # оновлюємо маніфест з tarball і переписуємо
    (out/"manifest.json").write_text(json.dumps(manifest, indent=2))
    return manifest

def verify(sid=None):
    snaps = sorted([d for d in SNAP.iterdir() if d.is_dir() and d.name.startswith("snap-")])
    if not snaps: return False, "no snapshots", 0
    target = SNAP / sid if sid else snaps[-1]
    mf = target / "manifest.json"
    if not mf.exists(): return False, f"no manifest in {target.name}", 0
    m = json.loads(mf.read_text())
    bad = []
    for rel, h in m.get("files", {}).items():
        f = target / rel
        if not f.exists() or sha256_file(f) != h:
            bad.append(rel)
    # перевірка sealed
    m2 = dict(m); expected = m2.pop("sealed", None); m2.pop("tarball", None); m2.pop("tarball_sha256", None)
    recalc = hashlib.sha256(canon(m2)).hexdigest()
    if expected != recalc: bad.append("manifest-sealed")
    return (len(bad)==0), bad, m.get("hash_tip",{}).get("index")

def list_snaps():
    snaps = sorted(SNAP.glob("snap-*"))
    for d in snaps:
        mf = d/"manifest.json"
        try: m = json.loads(mf.read_text())
        except Exception: m = {}
        sz = (SNAP / (m.get("tarball") or "")).stat().st_size if m.get("tarball") and (SNAP/(m.get("tarball") or "")).exists() else 0
        print(f"  {d.name}  score={m.get('score')}  hash_tip={m.get('hash_tip',{}).get('index')}  "
              f"files={len(m.get('files',{}))}  {sz//1024}KB")

def restore(sid, dry=False):
    target = SNAP / sid if sid else sorted(SNAP.glob("snap-*"))[-1]
    if not target.exists(): print(f"!! {target} not found"); return False
    ok, bad, _ = verify(target.name)
    if not ok: print(f"!! snapshot verification failed: {bad[:3]}..."); return False
    m = json.loads((target/"manifest.json").read_text())
    print(f">>> restore {target.name} (score={m.get('score')})")
    if dry:
        for rel in m.get("files",{}): print(f"    would restore: {rel}")
        return True
    # dump
    if (target/"dump.pm2").exists():
        shutil.copy2(PM2_HOME/"dump.pm2", PM2_HOME/f"dump.pm2.before-restore-{int(time.time())}") if (PM2_HOME/"dump.pm2").exists() else None
        shutil.copy2(target/"dump.pm2", PM2_HOME/"dump.pm2")
    # controllers
    if (target/"controllers").exists():
        for f in (target/"controllers").glob("*"):
            dst = (BIN/f.name) if f.suffix in (".py",".sh") and f.name.startswith("cybra_") else (HOME/"bin"/f.name)
            shutil.copy2(f, dst); os.chmod(dst, 0o755)
    # conf
    if (target/"conf").exists():
        for f in (target/"conf").glob("*.json"):
            shutil.copy2(f, CTL/f.name)
    # crontab
    if (target/"crontab.txt").exists():
        subprocess.run(["crontab","-"], input=(target/"crontab.txt").read_bytes(), check=False)
    print(">>> restored. now: pm2 kill && pm2 resurrect")
    return True

def main():
    a = sys.argv[1] if len(sys.argv)>1 else "list"
    if a == "create":
        m = capture(); print(f"OK {m['id']} score={m['score']} files={len(m['files'])} hash_tip={m.get('hash_tip',{}).get('index')}")
    elif a == "verify":
        ok, bad, idx = verify(sys.argv[2] if len(sys.argv)>2 else None)
        print(("OK" if ok else "BROKEN") + f" blocks={idx}" + ("" if ok else f" bad={bad[:3]}"))
        sys.exit(0 if ok else 1)
    elif a == "list": list_snaps()
    elif a == "restore":
        if len(sys.argv)<3: print("usage: restore <snap-id>"); return
        restore(sys.argv[2], dry="--dry" in sys.argv)
    elif a == "latest":
        snaps = sorted(SNAP.glob("snap-*"))
        print(snaps[-1].name if snaps else "(none)")
    else: print("cmds: create | verify [id] | list | restore <id> [--dry] | latest")

if __name__ == "__main__": main()
