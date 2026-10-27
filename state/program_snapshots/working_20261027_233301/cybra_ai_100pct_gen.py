#!/usr/bin/env python3
"""Генерує state/ai_tasks/mapping.json — повний module→executor→controller mapping."""
import os, sys, re, json, subprocess
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
OUT = CYBRA / "state/ai_tasks/mapping.json"
OUT.parent.mkdir(parents=True, exist_ok=True)

def find_module(n):
    for pat in [f"module_{n:03d}_base", f"module_{n}_base",
                f"module_0{n}_base" if n < 10 else None,
                f"module_00{n}_base" if n < 10 else None,
                f"module_{n:03d}_*", f"module_{n}_*",
                f"module_0{n}_*" if n < 10 else None,
                f"module_00{n}_*" if n < 10 else None]:
        if not pat: continue
        for d in sorted((CYBRA/"modules").glob(pat)):
            if d.is_dir() and (d/"main.sh").exists():
                return d
    return None

def classify_module(main_path):
    if not main_path or not Path(main_path).exists():
        return "missing"
    txt = Path(main_path).read_text(errors="ignore")
    if "── git ──" in txt or "════ taxi" in txt: return "stub"
    r = subprocess.run(["bash", str(main_path), "list"],
                       capture_output=True, timeout=10, input="")
    return "real" if r.returncode == 0 else "broken"

def main():
    # SPEC
    spec = {}
    sp = CYBRA/"state/modules_spec.json"
    if sp.exists():
        try: spec = json.loads(sp.read_text()).get("modules", {})
        except: pass
    for fname in ["taxi_spec.json","taxi_premium_spec.json","taxi_ultra_spec.json"]:
        fp = CYBRA/"state"/fname
        if not fp.exists(): continue
        try:
            for k, v in json.loads(fp.read_text()).get("modules", {}).items():
                spec[k] = {"name": v.get("name") or v.get("action") or f"module_{k}",
                           "category": v.get("category") or v.get("cat") or "custom"}
        except: pass

    modules = {}
    for n in range(1, 161):
        d = find_module(n)
        if not d: 
            modules[n] = {"n": n, "status": "missing", "target": None}
            continue
        main = d/"main.sh"
        info = spec.get(str(n), {"name": f"module_{n}", "category": "custom"})
        cls = classify_module(main)
        modules[n] = {
            "n": n,
            "name": info.get("name"),
            "category": info.get("category"),
            "dir": d.name,
            "target": str(main),
            "status": cls,
            "executor": "cybra_ai_executor.sh" if cls != "real" else "none",
            "controller": str(CYBRA/"controllers"/f"module_{n:03d}.ctrl.sh"),
            "snapshot": str(CYBRA/"state/snapshots"/f"module_{n:03d}.json"),
            "hidl_action": "write_module",
            "on_fail": "push_to_parliament_queue"
        }

    for n in range(200, 273):
        d = find_module(n)
        if not d:
            modules[n] = {"n": n, "status": "missing", "target": None}
            continue
        main = d/"main.sh"
        info = spec.get(str(n), {"name": f"module_{n}", "category": "taxi"})
        cls = classify_module(main)
        modules[n] = {
            "n": n,
            "name": info.get("name"),
            "category": info.get("category"),
            "dir": d.name,
            "target": str(main),
            "status": cls,
            "executor": "cybra_ai_executor.sh" if cls != "real" else "none",
            "controller": str(CYBRA/"controllers"/f"module_{n:03d}.ctrl.sh"),
            "snapshot": str(CYBRA/"state/snapshots"/f"module_{n:03d}.json"),
            "hidl_action": "write_module",
            "on_fail": "push_to_parliament_queue"
        }

    # PM2
    pm2_procs = []
    try:
        r = subprocess.run(["pm2","jlist"], capture_output=True, text=True, timeout=5)
        for p in json.loads(r.stdout):
            pm2_procs.append({"name": p["name"], "status": p["pm2_env"]["status"],
                              "controller": str(CYBRA/"state/snapshots"/f"pm2_{p['name']}.json")})
    except: pass

    # dart
    dart_files = []
    for f in (CYBRA/"flutter/cybra_taxi/lib").rglob("*.dart"):
        dart_files.append({"path": str(f), "snapshot": str(CYBRA/"state/snapshots"/f"dart_{f.stem}.json")})

    # api
    api_eps = []
    server = CYBRA/"api/server.py"
    if server.exists():
        for m in re.finditer(r'@app\.(get|post|delete)\("(/[^"]+)"', server.read_text()):
            api_eps.append({"method": m.group(1).upper(), "path": m.group(2)})

    # by status
    by_status = {}
    for m in modules.values():
        by_status.setdefault(m["status"], []).append(m["n"])

    mapping = {
        "generated": datetime.now(timezone.utc).isoformat(),
        "summary": {
            "modules_total": len(modules),
            "real": len(by_status.get("real",[])),
            "stub": len(by_status.get("stub",[])),
            "broken": len(by_status.get("broken",[])),
            "missing": len(by_status.get("missing",[])),
            "pm2": len(pm2_procs),
            "dart": len(dart_files),
            "api": len(api_eps),
        },
        "modules": modules,
        "pm2": pm2_procs,
        "dart": dart_files,
        "api": api_eps,
        "by_status": by_status,
    }
    OUT.write_text(json.dumps(mapping, indent=2, ensure_ascii=False))
    print(f"✅ mapping: {OUT}")
    print(f"   total: {mapping['summary']['modules_total']}")
    print(f"   real: {mapping['summary']['real']}  stub: {mapping['summary']['stub']}  broken: {mapping['summary']['broken']}  missing: {mapping['summary']['missing']}")
    print(f"   pm2: {len(pm2_procs)}  dart: {len(dart_files)}  api: {len(api_eps)}")

if __name__ == "__main__":
    main()
