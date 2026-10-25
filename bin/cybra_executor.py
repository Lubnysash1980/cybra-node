#!/usr/bin/env python3
"""Executor — reads executor_mapping.json, picks best per rule, improves, never shrinks."""
import os, re, sys, json, tarfile, subprocess, shutil, tempfile, hashlib
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MAP = CYBRA / "state/executors/executor_mapping.json"
OUT_PLAN = CYBRA / "state/executors/plan.json"
OUT_APPLY = CYBRA / "state/executors/applied.json"
BUILD = CYBRA / "state/executors/build"
BACKUP = CYBRA / "state/executors/backup"

def log(m): print(m, flush=True)
cfg = json.loads(MAP.read_text())
STUB = [s.lower() for s in cfg["scoring"]["stub_markers"]]
REAL = [s.lower() for s in cfg["scoring"]["real_markers"]]

def is_stub(t):
    low = t.lower()
    return any(m in low for m in STUB) or (len(t) < 400 and not any(m in low for m in REAL))

def score(t):
    if is_stub(t): return -1
    low = t.lower()
    return sum(1 for m in REAL if m in low) * 100 + len(t) // 100

def syntax_ok(t):
    p = CYBRA / ".exe_chk.sh"; p.write_text(t)
    try: return subprocess.run(["bash","-n",str(p)], capture_output=True).returncode == 0
    finally: p.unlink(missing_ok=True)

def git_show(rev, relpath):
    r = subprocess.run(["git","show",f"{rev}:{relpath}"], cwd=CYBRA, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 and r.stdout else None

def git_commit_date(rev):
    r = subprocess.run(["git","show","-s","--format=%cI",rev], cwd=CYBRA, capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else "?"

def mod_dir_name(n):
    for p in sorted((CYBRA/"modules").iterdir()):
        if p.is_dir() and re.match(rf"module_0*{n}(?:[_\d].*)?$", p.name):
            return p.name
    return None

def all_versions(n):
    out = []
    d = mod_dir_name(n)
    relpath = f"modules/{d}/main.sh" if d else None

    # source 1: github_remote (origin/main)
    if relpath:
        subprocess.run(["git","fetch","origin","main","-q"], cwd=CYBRA, capture_output=True)
        c = git_show("origin/main", relpath)
        if c and syntax_ok(c) and not is_stub(c):
            out.append({"src":"github_remote","rev":"origin/main","content":c,
                        "score":score(c),"size":len(c),"when":"?"})

    # source 2: git history (all commits touching file)
    if relpath:
        r = subprocess.run(["git","log","--all","--format=%H","--",relpath],
                           cwd=CYBRA, capture_output=True, text=True)
        for commit in r.stdout.splitlines()[:cfg["rules"]["max_candidates_per_module"]]:
            c = git_show(commit, relpath)
            if c and syntax_ok(c) and not is_stub(c):
                out.append({"src":"github_history","rev":commit[:8],"content":c,
                            "score":score(c),"size":len(c),"when":git_commit_date(commit)})

    # source 3: snapshots
    for tb in sorted((CYBRA/"snapshots").glob("*.tar.gz")):
        try:
            td = Path(tempfile.mkdtemp(prefix="exe_"))
            with tarfile.open(tb, "r:gz") as t: t.extractall(td)
            for mdir in td.rglob("modules"):
                if not mdir.is_dir(): continue
                for candidate in mdir.glob(f"module_{n:03d}_*"):
                    main = candidate / "main.sh"
                    if main.exists():
                        c = main.read_text(errors="ignore")
                        if syntax_ok(c) and not is_stub(c):
                            out.append({"src":"snapshots","rev":tb.stem,"content":c,
                                        "score":score(c),"size":len(c),"when":"snap"})
                        break
                break
            shutil.rmtree(td, ignore_errors=True)
        except Exception:
            pass

    # source 4: sdcard + storage (flash recovery) — OPT-IN
    import glob as _g
    if os.environ.get("CYBRA_SCAN_SDCARD") != "1":
        pass  # skip, див. CYBRA_SCAN_SDCARD=1 cybra_executor.py plan
    else:

        roots = ["/sdcard", "/storage/emulated/0"]
        try:
            roots += [str(p) for p in Path("/storage").iterdir() if p.is_dir()]
        except Exception: pass
        seen_dirs = set()
        for base in roots:
            # шукаємо будь-який шлях, що містить 'modules' і нашу папку
            patterns = [
                f"{base}/**/modules/module_{n:03d}_*",
                f"{base}/**/modules/module_{n}_*",
                f"{base}/**/CYBRA/modules/module_{n:03d}_*",
                f"{base}/**/*відновлення*/**/modules/module_{n:03d}_*",
            ]
            for pat in patterns:
                try:
                    hits = _g.glob(pat, recursive=True)[:5]
                except Exception:
                    hits = []
                for hit in hits:
                    hp = Path(hit)
                    if str(hp) in seen_dirs or not hp.is_dir(): continue
                    seen_dirs.add(str(hp))
                    main = hp / "main.sh"
                    if not main.exists(): continue
                    try:
                        c = main.read_text(errors="ignore")
                        if syntax_ok(c) and not is_stub(c):
                            out.append({"src":"sdcard","rev":str(main.parent),
                                        "content":c,"score":score(c),
                                        "size":len(c),"when":"sdcard"})
                    except Exception: pass

    # source 5: current
    if d:
        cur = CYBRA/"modules"/d/"main.sh"
        if cur.exists():
            c = cur.read_text(errors="ignore")
            if syntax_ok(c):
                out.append({"src":"current","rev":"HEAD","content":c,
                            "score":score(c),"size":len(c),"when":"now"})
    # dedupe by hash
    seen, uniq = set(), []
    for c in out:
        h = hashlib.sha256(c["content"].encode()).hexdigest()[:12]
        if h in seen: continue
        seen.add(h); c["hash"] = h; uniq.append(c)
    uniq.sort(key=lambda c: (-c["score"], -c["size"]))
    return uniq

def with_header(n, c):
    header = (f"#!/data/data/com.termux/files/usr/bin/bash\n"
              f"# ── BINMIX/EXECUTOR METADATA (auto-added) ──\n"
              f"# module: module_{n:03d}\n"
              f"# source: {c['src']}  rev={c['rev']}  when={c['when']}\n"
              f"# score: {c['score']}  size: {c['size']}B  hash: {c['hash']}\n"
              f"# mixed_at: {datetime.now(timezone.utc).isoformat()}\n"
              f"# ──────────────────────────────────────────\n")
    body = c["content"]
    if body.startswith("#!"):
        body = body.split("\n",1)[1] if "\n" in body else ""
    return header + body

def cmd_plan():
    log("═══ EXECUTOR PLAN (no changes) ═══")
    log(f"mapping: {MAP}")
    plan = {"generated_at": datetime.now(timezone.utc).isoformat(), "modules": {}}
    stats = {"improve":0,"keep":0,"needs_author":0}
    targets = list(range(1,281))
    for n in targets:
        cands = all_versions(n)
        best = cands[0] if cands else None
        cur = next((c for c in cands if c["src"]=="current"), None)
        if not best or best["score"] < 0:
            action = "needs_author"
        elif cur and best["src"] == "current":
            action = "keep"
        elif cur and best["size"] < (cur["size"] if cur else 0):
            action = "keep"
        else:
            action = "improve"
        stats[action] += 1
        plan["modules"][n] = {"action":action,
                              "best":{k:best[k] for k in ("src","rev","score","size","when")} if best else None,
                              "current":{"src":"current","score":cur["score"],"size":cur["size"]} if cur else None,
                              "candidates":len(cands)}
        if n % 50 == 0: log(f"  ... scanned {n}")
    OUT_PLAN.parent.mkdir(parents=True, exist_ok=True)
    OUT_PLAN.write_text(json.dumps({"stats":stats, "plan":plan}, indent=2, ensure_ascii=False))
    log(f"✅ improve={stats['improve']} keep={stats['keep']} needs_author={stats['needs_author']}")
    log(f"→ {OUT_PLAN}")

def cmd_apply():
    if not OUT_PLAN.exists(): log("!! no plan; run: cybra_executor.py plan"); return 1
    plan = json.loads(OUT_PLAN.read_text())["plan"]["modules"]
    BACKUP.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    subprocess.run(["tar","-czf",str(BACKUP/f"modules_{ts}.tar.gz"),"-C",str(CYBRA),"modules"], check=True)
    log(f"  backup: modules_{ts}.tar.gz")
    improved = 0
    for n_str, entry in plan.items():
        if entry["action"] != "improve": continue
        if (CYBRA/"state/executors/blacklist.json").exists():
            try:
                bl = json.loads((CYBRA/"state/executors/blacklist.json").read_text())
                if str(n_str) in bl:
                    log(f"  skip module {n_str} (blacklisted)")
                    continue
            except: pass
        n = int(n_str); d = mod_dir_name(n)
        if not d: continue
        cands = all_versions(n)
        best = cands[0]
        dst = CYBRA/"modules"/d/"main.sh"
        dst.write_text(with_header(n, best))
        os.chmod(dst, 0o755)
        improved += 1
        if improved % 25 == 0: log(f"  ... improved {improved}")
    OUT_APPLY.write_text(json.dumps({"applied_at":datetime.now(timezone.utc).isoformat(),
                                     "improved":improved}, indent=2))
    log(f"✅ improved {improved} modules")
    log(f"→ {OUT_APPLY}")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv)>1 else "plan"
    {"plan":cmd_plan, "apply":cmd_apply}.get(cmd, lambda: log("usage: plan|apply"))()
