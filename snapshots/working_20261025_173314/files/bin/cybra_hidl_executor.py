#!/usr/bin/env python3
"""HIDL Executor: одна задача з worker.
   1. запускає ctrl_NNN.sh (він перевіряє main.sh + запускає)
   2. якщо evo.check → рахує score, порівнює з baseline, поріг 3%
   3. якщо git.access і rc!=0 → намагається git restore
   4. пише response у stdout (JSON)
"""
import os, re, sys, json, subprocess, time, hashlib
from pathlib import Path
from datetime import datetime, timezone

CYBRA  = Path(os.environ["HOME"]) / "CYBRA"
BASELINE = CYBRA / "state/evo_baseline.json"
BACKUP_DIR = CYBRA / "state/hidl_backups"
BACKUP_DIR.mkdir(parents=True, exist_ok=True)

REAL_RE = re.compile(r'redis-cli|git --no-pager|pm2 jlist|python3 |cybra_|sqlite|curl|fidic', re.I)

def score_text(t):
    """Score одного файлу."""
    lines = len(t.splitlines())
    calls = len(REAL_RE.findall(t))
    funcs = len(re.findall(r'^\w+\s*\(\)\s*\{', t, re.M))
    has_err = bool(re.search(r'\btrap\b|set -e|set -u|\|\| exit', t))
    has_log = bool(re.search(r'>\s*"\$LOG"|tee -a|log\(\)\s*\{', t))
    has_args = bool(re.search(r'\$\{?[1@#]\}?\b|getopts|case\s+"\$\{?1', t))
    return round(lines/10 + calls*5 + funcs*3 + (10 if has_err else 0) + (10 if has_log else 0) + (5 if has_args else 0), 2)

def git_restore(main_path):
    """Відновити main.sh з git HEAD. Працює для tracked modified файлів.
       Для untracked — пробує evo_backups як fallback."""
    if not main_path.exists(): return False
    try:
        rel = str(main_path.relative_to(CYBRA))
    except: return False

    # 1. Перевір чи файл tracked
    ls = subprocess.run(["git","ls-files",rel], cwd=CYBRA, capture_output=True, text=True, timeout=10)
    is_tracked = bool(ls.stdout.strip())

    # 2. Спробувати git-restore
    if is_tracked:
        for cmd in [
            ["git","checkout","-f","HEAD","--",rel],
            ["git","restore","--source=HEAD","--worktree","--staged","--",rel],
            ["git","checkout","HEAD","--",rel],
        ]:
            try:
                r = subprocess.run(cmd, cwd=CYBRA, capture_output=True, text=True, timeout=15)
                if r.returncode == 0:
                    # verify: файл не починається з # BROKEN
                    txt = main_path.read_text(errors="ignore")
                    if len(txt) > 200 and not txt.lstrip().startswith("# BROKEN"):
                        return True
            except: pass

    # 3. Fallback: останній backup з evo_backups/ (module_NNN_*.sh)
    import re as _re
    n_m = _re.search(r"module_0*(\d+)", main_path.parent.name)
    if n_m:
        n = int(n_m.group(1))
        backup_dirs = [
            CYBRA / "state/evo_premium_backups",
            CYBRA / "state/evo_upgrade_backups",
            CYBRA / "state/evo_backups",
        ]
        candidates = []
        for bd in backup_dirs:
            if bd.exists():
                candidates.extend(bd.glob(f"module_{n:03d}_*.sh"))
        if candidates:
            latest = max(candidates, key=lambda f: f.stat().st_mtime)
            try:
                import shutil as _sh
                _sh.copy2(latest, main_path)
                txt = main_path.read_text(errors="ignore")
                if len(txt) > 200:
                    return True
            except: pass

    # 4. LAST RESORT: git show HEAD:rel > rel
    if is_tracked:
        try:
            r = subprocess.run(["git","show",f"HEAD:{rel}"], cwd=CYBRA,
                               capture_output=True, text=True, timeout=15)
            if r.returncode == 0 and len(r.stdout) > 200:
                main_path.write_text(r.stdout)
                return True
        except: pass

    return False

def run_hidl(msg):
    t0 = time.time()
    n = msg.get("module", 0)
    action = msg.get("action", "execute")
    spec = msg.get("spec", {})
    ctrl = msg.get("ctrl")
    main = msg.get("main")
    args = msg.get("args", [])
    evo = msg.get("evo", {})
    git_ = msg.get("git", {})

    resp = {"status":"ok", "rc":0, "stdout":"", "stderr":"",
            "score_before":None, "score_after":None, "delta_pct":0.0,
            "git_restore":False, "elapsed_sec":0}

    # score before
    if main and Path(main).exists():
        before = score_text(Path(main).read_text(errors="ignore"))
        resp["score_before"] = before

    # verify action = тільки перевірка, без запуску — АЛЕ з EVO check
    if action in ("verify", "score"):
        resp["stdout"] = f"verify-only module={n} score={resp['score_before']}"
        # EVO: порівнюємо з baseline через evo_baseline avg
        if evo.get("check") and BASELINE.exists():
            try:
                base_avg = json.loads(BASELINE.read_text()).get("avg", 0)
                base_mods = json.loads(BASELINE.read_text()).get("modules", {})
                base_score = base_mods.get(str(n), {}).get("score") if base_mods else None
                ref = base_score if base_score else resp["score_before"]
                if ref and ref > 0 and resp["score_before"] is not None:
                    delta = (resp["score_before"] - ref) / ref * 100
                    resp["delta_pct"] = round(delta, 2)
                    if abs(delta) >= evo.get("threshold_pct", 3.0) and delta < 0:
                        resp["status"] = "degraded"
                        if evo.get("on_rollback") == "restore_from_git" and git_.get("access"):
                            if git_restore(Path(main)):
                                resp["git_restore"] = True
                                resp["status"] = "rolled_back"
                                # post-restore score
                                if main and Path(main).exists():
                                    resp["score_after"] = score_text(Path(main).read_text(errors="ignore"))
            except Exception as e:
                resp["stderr"] = f"evo_err:{e}"
        resp["elapsed_sec"] = round(time.time()-t0, 2)
        return resp

    # execute через ctrl або напряму
    if ctrl and Path(ctrl).exists() and Path(ctrl).is_file():
        cmd = ["bash", ctrl, main] + args
    elif main and Path(main).exists():
        cmd = ["bash", main] + args
    else:
        resp["status"] = "fail"
        resp["stderr"] = "no ctrl or main"
        resp["rc"] = 2
        resp["elapsed_sec"] = round(time.time()-t0, 2)
        return resp

    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=45, input="\n")
        resp["rc"] = r.returncode
        resp["stdout"] = r.stdout[:500]
        resp["stderr"] = r.stderr[:500]
        if r.returncode != 0:
            resp["status"] = "fail"
    except subprocess.TimeoutExpired:
        resp["status"] = "fail"; resp["rc"] = 124; resp["stderr"] = "timeout 45s"
    except Exception as e:
        resp["status"] = "fail"; resp["rc"] = 1; resp["stderr"] = str(e)[:200]

    # score after
    if main and Path(main).exists():
        after = score_text(Path(main).read_text(errors="ignore"))
        resp["score_after"] = after

    # EVO 3% check
    if evo.get("check") and BASELINE.exists():
        try:
            base = json.loads(BASELINE.read_text()).get("avg", 0)
            if base > 0 and resp["score_before"] is not None and resp["score_after"] is not None:
                delta = (resp["score_after"] - resp["score_before"]) / max(resp["score_before"], 1) * 100
                resp["delta_pct"] = round(delta, 2)
                if abs(delta) >= evo.get("threshold_pct", 3.0):
                    resp["status"] = "degraded" if delta < 0 else "improved"
                    if delta < 0 and evo.get("on_rollback") == "restore_from_git" and git_.get("access"):
                        log = CYBRA / "logs/hidl_executor.log"
                        with open(log, "a") as f:
                            f.write(f"[{datetime.now().isoformat()}] evo {delta:+.2f}% on module {n} → git restore\n")
                        if git_restore(Path(main)):
                            resp["git_restore"] = True
                            resp["status"] = "rolled_back"
        except Exception as e:
            resp["stderr"] += f" | evo_err:{e}"

    # git restore при rc!=0 (незалежно від evo)
    if resp["rc"] != 0 and git_.get("access") and git_.get("on_error") == "restore":
        if git_restore(Path(main)):
            resp["git_restore"] = True
            # повторна спроба
            try:
                r2 = subprocess.run(cmd, capture_output=True, text=True, timeout=45, input="\n")
                resp["rc"] = r2.returncode
                resp["stdout"] = r2.stdout[:500]
                if r2.returncode == 0:
                    resp["status"] = "ok"
            except: pass

    resp["elapsed_sec"] = round(time.time()-t0, 2)
    return resp

def main():
    raw = sys.stdin.read()
    if not raw.strip():
        print(json.dumps({"status":"fail","error":"empty stdin"})); sys.exit(0)
    try:
        msg = json.loads(raw)
    except Exception as e:
        print(json.dumps({"status":"fail","error":f"bad json: {e}"})); sys.exit(0)
    resp = run_hidl(msg)
    print(json.dumps(resp, ensure_ascii=False))

if __name__ == "__main__":
    main()
