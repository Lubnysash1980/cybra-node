#!/usr/bin/env python3
"""AUTOPATCH DAEMON — автоматично бекапить 100% state на storage при появі.
   Слухає:
   - git remote (github.com через ls-remote кожні 5 хв)
   - storage paths (/storage/*, /mnt/media_rw/*) кожні 30 сек
   Коли storage з'явився і ще нема свіжого бекапу (<6h) → робить бекап.
"""
import os, sys, re, json, time, subprocess, hashlib, shutil
from pathlib import Path
from datetime import datetime, timezone, timedelta

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
LOG = CYBRA / "logs/autopatch.log"
STATE = CYBRA / "state/autopatch_state.json"
MASTER = CYBRA / "state/snapshots/_master.json"
TMP = Path(os.environ["HOME"]) / "tmp"
TMP.mkdir(exist_ok=True)
LOG.parent.mkdir(exist_ok=True)

STORAGE_PATHS = [
    "/storage/0123-4567",
    "/mnt/media_rw/0020-F2A1",
]
GIT_REMOTE_CHECK_INTERVAL = 300     # 5 хв
STORAGE_CHECK_INTERVAL = 30         # 30 сек
BACKUP_MIN_AGE_H = 6                # якщо бекап старіший — оновити
KEEP_COPIES = 3
NEED_SPACE_MB = 500

def log(m):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{t}] {m}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

def now():
    return datetime.now(timezone.utc)

def state_100():
    if not MASTER.exists(): return False, "no master"
    try:
        d = json.loads(MASTER.read_text())
        pct = d.get("pct", 0)
        return (pct == 100 or pct == 100.0), f"{pct}%"
    except Exception as e:
        return False, str(e)

def git_head():
    try:
        r = subprocess.run(["git","rev-parse","HEAD"], cwd=CYBRA,
                          capture_output=True, text=True, timeout=5)
        return r.stdout.strip()[:12] if r.returncode == 0 else "?"
    except: return "?"

def git_pull():
    """Автопатч: pull останніх змін з GitHub"""
    try:
        r = subprocess.run(["git","pull","--no-rebase","origin","main"],
                          cwd=CYBRA, capture_output=True, text=True, timeout=60)
        if r.returncode == 0:
            if "Already up to date" in r.stdout or "Already up-to-date" in r.stdout:
                return True, "up-to-date"
            return True, "pulled: " + r.stdout.strip().splitlines()[-1][:80] if r.stdout else "pulled"
        return False, r.stderr[-100:]
    except Exception as e:
        return False, str(e)

def storage_available():
    """Повертає список mounted writable storage з CYBRA_BACKUP"""
    out = []
    for p in STORAGE_PATHS:
        pth = Path(p)
        if not pth.exists(): continue
        try:
            test = pth / ".cybra_test"
            test.write_text("x"); test.unlink()
        except: continue
        free = shutil.disk_usage(str(pth)).free // (1024*1024)
        out.append({"path": p, "backup_dir": str(pth / "CYBRA_BACKUP"), "free_mb": free})
    return out

def latest_backup_age_h(storage_path):
    """Скільки годин з останнього бекапу на цьому storage"""
    bd = Path(storage_path) / "CYBRA_BACKUP"
    if not bd.exists(): return 999
    bundles = sorted(bd.glob("cybra_*.bundle"), key=lambda f: f.stat().st_mtime)
    if not bundles: return 999
    age_sec = time.time() - bundles[-1].stat().st_mtime
    return age_sec / 3600

def create_backup(ts):
    """Створити bundle + tar.gz + SHA256SUMS"""
    bundle = Path(os.environ["HOME"]) / f"cybra_{ts}.bundle"
    tarball = Path(os.environ["HOME"]) / f"cybra_working_{ts}.tar.gz"
    checks  = Path(os.environ["HOME"]) / f"cybra_{ts}_SHA256SUMS.txt"

    # git bundle
    r = subprocess.run(["git","bundle","create",str(bundle),"--all"],
                      cwd=CYBRA, capture_output=True, text=True, timeout=120)
    if r.returncode != 0:
        return None, f"bundle fail: {r.stderr[-100:]}"

    # tar.gz
    excludes = [
        "--exclude=node_modules","--exclude=state/module_backups",
        "--exclude=state/autobuild_backup_*","--exclude=state/evo_*backups",
        "--exclude=state/hidl_backups","--exclude=state/tag_backup",
        "--exclude=state/named_backup","--exclude=state/backup",
        "--exclude=logs","--exclude=snapshots","--exclude=sandbox",
        "--exclude=.binmix/snapshots","--exclude=*.pyc",
        "--exclude=*.tar.gz","--exclude=*.bundle",
    ]
    r = subprocess.run(["tar","-czf",str(tarball),*excludes,
                       "-C",str(Path(os.environ["HOME"])),"CYBRA"],
                      capture_output=True, text=True, timeout=300)
    if r.returncode != 0:
        return None, f"tar fail: {r.stderr[-100:]}"

    # checksums
    def sha(p):
        h = hashlib.sha256()
        with open(p,"rb") as f:
            for chunk in iter(lambda: f.read(1024*1024), b""):
                h.update(chunk)
        return h.hexdigest()

    b_sha, t_sha = sha(bundle), sha(tarball)
    ok, pct = state_100()
    head = git_head()
    checks.write_text(
        f"# CYBRA autopatch {ts}\n"
        f"# state={pct} git={head}\n"
        f"{b_sha}  {bundle.name}\n"
        f"{t_sha}  {tarball.name}\n"
    )
    return {"bundle": str(bundle), "tarball": str(tarball), "checks": str(checks),
            "bundle_sha": b_sha, "tar_sha": t_sha,
            "bundle_size": bundle.stat().st_size,
            "tar_size": tarball.stat().st_size}, None

def copy_to_storage(storage, files):
    """Копіює + верифікує sha256"""
    bd = Path(storage["backup_dir"])
    bd.mkdir(parents=True, exist_ok=True)
    results = {}
    for key in ("bundle","tarball","checks"):
        src = Path(files[key])
        dst = bd / src.name
        shutil.copy2(src, dst)
        results[key] = str(dst)
    # verify
    for pair, key in [("bundle","bundle_sha"), ("tarball","tar_sha")]:
        name = Path(files[pair]).name
        expected = files[key]
        if key == "bundle_sha":
            line = f"{expected}  {name}"
        else:
            line = f"{expected}  {name}"
        # sha256sum -c
        r = subprocess.run(["sha256sum","-c","-"], input=line, text=True,
                          capture_output=True, cwd=str(bd), timeout=120)
        if r.returncode != 0:
            return False, f"sha mismatch: {name}"
    # rotate
    for pat in ("cybra_*.bundle","cybra_working_*.tar.gz","cybra_*_SHA256SUMS.txt"):
        lst = sorted(bd.glob(pat), key=lambda f: f.stat().st_mtime, reverse=True)
        for old in lst[KEEP_COPIES:]:
            old.unlink()
    return True, "ok"

def autopatch(trigger):
    """Повний autopatch цикл для одного trigger"""
    ok, pct = state_100()
    if not ok:
        log(f"  SKIP ({trigger}): state={pct} (треба 100%)")
        return False

    storages = storage_available()
    if not storages:
        log(f"  SKIP ({trigger}): no writable storage")
        return False

    # які storage потребують бекапу (> 6h або 0 файлів)
    need = [s for s in storages if latest_backup_age_h(s["path"]) >= BACKUP_MIN_AGE_H]
    if not need:
        log(f"  SKIP ({trigger}): all storages fresh (< {BACKUP_MIN_AGE_H}h)")
        return True

    # достатньо місця?
    need = [s for s in need if s["free_mb"] >= NEED_SPACE_MB]
    if not need:
        log(f"  SKIP ({trigger}): insufficient space (< {NEED_SPACE_MB}MB)")
        return False

    ts = now().strftime("%Y%m%d_%H%M%S")
    log(f"  BACKUP ({trigger}) → {len(need)} storages, ts={ts}")

    files, err = create_backup(ts)
    if err:
        log(f"  ❌ backup fail: {err}")
        return False

    log(f"  ✅ bundle: {files['bundle_size']//1024}KB sha={files['bundle_sha'][:16]}")
    log(f"  ✅ tar:    {files['tar_size']//1024}KB sha={files['tar_sha'][:16]}")

    for s in need:
        ok, msg = copy_to_storage(s, files)
        if ok:
            log(f"  ✅ copied → {s['backup_dir']}")
        else:
            log(f"  ❌ copy fail {s['path']}: {msg}")

    # cleanup home
    try:
        os.unlink(files["bundle"]); os.unlink(files["tarball"]); os.unlink(files["checks"])
    except: pass

    # persist
    STATE.write_text(json.dumps({
        "ts": now().isoformat(),
        "trigger": trigger,
        "pct": pct,
        "head": git_head(),
        "storages": [s["path"] for s in need],
        "bundle_sha": files["bundle_sha"][:16],
        "tar_sha": files["tar_sha"][:16],
    }, indent=2, ensure_ascii=False))
    return True

def run_loop():
    log("═══ AUTOPATCH DAEMON START ═══")
    log(f"  storage paths: {len(STORAGE_PATHS)}")
    for p in STORAGE_PATHS: log(f"    - {p}")
    log(f"  git check:     {GIT_REMOTE_CHECK_INTERVAL}s")
    log(f"  storage check: {STORAGE_CHECK_INTERVAL}s")
    log(f"  min age:       {BACKUP_MIN_AGE_H}h")

    last_git = 0
    seen_storages = set()

    while True:
        try:
            # 1. git pull кожні N сек
            if time.time() - last_git >= GIT_REMOTE_CHECK_INTERVAL:
                ok, msg = git_pull()
                if ok and "pulled" in msg and "up-to-date" not in msg:
                    log(f"  🔄 GIT: {msg}")
                    # після pull — негайно autopatch (бо код змінився)
                    autopatch("git-pull")
                last_git = time.time()

            # 2. storage моніторинг
            curr = set()
            for s in storage_available():
                curr.add(s["path"])
                if s["path"] not in seen_storages:
                    log(f"  🔌 STORAGE: {s['path']} появився")
                    autopatch(f"storage-connected:{s['path']}")

            for gone in seen_storages - curr:
                log(f"  🔌 STORAGE: {gone} відключено")
            seen_storages = curr

            # 3. periodic check (якщо є storage — перевірити age)
            if seen_storages:
                for s in storage_available():
                    age = latest_backup_age_h(s["path"])
                    if age >= BACKUP_MIN_AGE_H:
                        autopatch(f"periodic:{s['path']}")
        except Exception as e:
            log(f"  ERR: {e}")
        time.sleep(STORAGE_CHECK_INTERVAL)

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "run"
    if cmd == "run":       run_loop()
    elif cmd == "once":    autopatch("manual")
    elif cmd == "check":   print(f"state: {state_100()}  storages: {storage_available()}")
    elif cmd == "pull":    print(git_pull())
    else: print("usage: run | once | check | pull")
