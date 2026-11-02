#!/usr/bin/env python3
"""cybra_stage_analytics.py — стейдж-нода для екзекуторів/воркерів.
Пише: node/stage_analytics.json, node/stage_history.jsonl, redis cybra:stage
"""
import json, os, subprocess, time, shutil
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(os.environ.get("CYBRA", Path.home()/"CYBRA"))
NODE = ROOT/"node"; NODE.mkdir(parents=True, exist_ok=True)
CUR = NODE/"stage_analytics.json"
HIST = NODE/"stage_history.jsonl"
GATE = ROOT/"state"/"golden_gate.json"

def sh(cmd, timeout=5):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, timeout=timeout, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""

def pm2():
    try:
        return json.loads(subprocess.check_output(["pm2","jlist"], text=True, timeout=10))
    except Exception:
        return []

def facts():
    procs = pm2()
    online = [p for p in procs if p["pm2_env"]["status"]=="online"]
    errored = [p for p in procs if p["pm2_env"]["status"]=="errored"]
    no65 = [p["name"] for p in online if p["pm2_env"].get("max_memory_restart") not in ("65M", None)]
    runaway = [p["name"] for p in procs if p["name"]!="redis" and (p["pm2_env"].get("restart_time",0) or 0)>200]

    # free RAM
    fm = sh("free -m").splitlines()
    ram_total = ram_used = ram_free = 0
    for ln in fm:
        if ln.startswith("Mem:"):
            parts = ln.split()
            ram_total, ram_used, ram_free = int(parts[1]), int(parts[2]), int(parts[-1])

    disk_mb = 0
    df = sh(f"df -Pk {ROOT} 2>/dev/null | tail -1").split()
    if len(df) >= 4:
        try: disk_mb = int(df[3]) // 1024
        except: pass

    qdir = ROOT/"queue"/"parliament"
    qn = len(list(qdir.glob("*.json"))) if qdir.exists() else 0

    return {
        "procs_total": len(procs),
        "online": len(online),
        "errored": len(errored),
        "stopped": len([p for p in procs if p["pm2_env"]["status"]=="stopped"]),
        "gods": int(sh('pgrep -f "PM2.*God Daemon" | wc -l') or 0),
        "no_65m": no65,
        "runaway": runaway,
        "redis": "PONG" if sh("redis-cli ping")=="PONG" else "DOWN",
        "api": "ok" if sh("curl -sf --max-time 3 http://127.0.0.1:8000/health -o /dev/null && echo ok")=="ok" else "fail",
        "queue": qn,
        "ram_total_mb": ram_total, "ram_used_mb": ram_used, "ram_free_mb": ram_free,
        "ram_free_pct": round(100*ram_free/ram_total, 1) if ram_total else 0,
        "disk_mb": disk_mb,
    }

def gates(f):
    return {
        "god_singleton": f["gods"]==1,
        "no_errored": f["errored"]==0,
        "min_online": f["online"]>=15,
        "all_65M": len(f["no_65m"])==0,
        "redis_pong": f["redis"]=="PONG",
        "api_health": f["api"]=="ok",
        "queue_sane": f["queue"]<500,
        "ram_ok": f["ram_free_pct"]>12,
        "no_runaway": len(f["runaway"])==0,
        "disk_ok": f["disk_mb"]>500,
    }

def stage(f, g):
    passed = sum(1 for v in g.values() if v)
    if f["gods"]==0: return 0, "DEAD"
    if f["online"]==0: return 1, "BOOT"
    if f["errored"]>3 or f["redis"]!="PONG" or f["api"]!="ok": return 2, "DEGRADED"
    if passed<10: return 3, "STABLE"
    if f["online"]<f["procs_total"]: return 4, "ONLINE"
    return 5, "GOLDEN"

def recommendations(f, g):
    rec = []
    if not g["god_singleton"]: rec.append(f"kill -9 $(pgrep -f 'PM2.*God Daemon'); pm2 resurrect ({f['gods']} gods)")
    if not g["no_errored"]: rec.append(f"{f['errored']} errored — pm2 restart all")
    if f["no_65m"]: rec.append(f"missing 65M: {','.join(f['no_65m'][:5])}")
    if not g["redis_pong"]: rec.append("redis down — pm2 start $(command -v redis-server)")
    if not g["api_health"]: rec.append("api down — tail ~/.pm2/logs/cybra-api-error.log")
    if not g["queue_sane"]: rec.append(f"queue={f['queue']} — find queue/parliament -mmin +5 -delete")
    if not g["ram_ok"]: rec.append(f"ram {f['ram_free_pct']}% free — close Android apps")
    if f["runaway"]: rec.append(f"runaway: {','.join(f['runaway'][:5])}")
    if not g["disk_ok"]: rec.append(f"disk {f['disk_mb']}MB — du -sh ~/CYBRA/*")
    return rec

def main():
    f = facts()
    g = gates(f)
    s, name = stage(f, g)
    rec = recommendations(f, g)

    # per-process snapshot для воркерів
    procs = {}
    for p in pm2():
        e = p["pm2_env"]
        procs[p["name"]] = {
            "status": e.get("status"),
            "restarts": e.get("restart_time", 0),
            "mem_limit": e.get("max_memory_restart"),
            "script": Path(e.get("pm_exec_path","")).name if e.get("pm_exec_path") else None,
        }

    now = time.time()
    payload = {
        "ts": now,
        "iso": datetime.fromtimestamp(now, tz=timezone.utc).isoformat(),
        "stage": s,
        "name": name,
        "gates_pass": f"{sum(1 for v in g.values() if v)}/10",
        "golden": s==5,
        "facts": f,
        "gates": g,
        "processes": procs,
        "recommendations": rec,
    }
    CUR.write_text(json.dumps(payload, indent=2, ensure_ascii=False))

    # history (тільки стисле)
    with HIST.open("a") as fh:
        fh.write(json.dumps({
            "ts": now, "stage": s, "name": name,
            "online": f"{f['online']}/{f['procs_total']}",
            "gates": payload["gates_pass"],
            "ram": f["ram_free_pct"], "queue": f["queue"], "disk": f["disk_mb"],
        })+"\n")

    # redis для воркерів
    sh(f"redis-cli SET cybra:stage {s} >/dev/null 2>&1")
    sh(f"redis-cli SET cybra:stage_name {name} >/dev/null 2>&1")
    sh(f"redis-cli SET cybra:stage_json '{json.dumps(payload, ensure_ascii=False)}' >/dev/null 2>&1")

    print(f"[{datetime.now():%H:%M:%S}] STAGE {s}/5 {name} | online {f['online']}/{f['procs_total']} | gates {payload['gates_pass']} | ram {f['ram_free_pct']}% | queue {f['queue']} | disk {f['disk_mb']}MB")
    return s

if __name__ == "__main__":
    exit(0 if main()==5 else 1)
