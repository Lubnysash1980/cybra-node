#!/data/data/com.termux/files/usr/bin/bash
# cybra_dump_components.sh — швидкий компонентний знімок. Без pm2.dump, без tar.
set -u
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
MAP="$CYBRA/bin/cybra_components.json"
[ -f "$MAP" ] || { echo "no components map"; exit 1; }

TS=$(date +%Y%m%d_%H%M%S)
D="$CYBRA/dumps/components/comp_$TS"
mkdir -p "$D"

pm2 jlist > "$CYBRA/.cache/pm2.json" 2>/dev/null || echo '[]' > "$CYBRA/.cache/pm2.json"

python3 - "$CYBRA" "$D" "$MAP" <<'PY'
import json, sys, os
from pathlib import Path
cybra, dump, mapf = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])
cmap = json.loads(mapf.read_text())
jl = json.loads((cybra/".cache"/"pm2.json").read_text())
by = {p["name"]: p for p in jl}

summary = {}
for cname, procs in cmap.items():
    present = [p for p in procs if p in by]
    on  = [p for p in present if by[p]["pm2_env"]["status"]=="online"]
    er  = [p for p in present if by[p]["pm2_env"]["status"]=="errored"]
    pct = round(100*len(on)/len(present),1) if present else 0
    score = int(pct - len(er)*20)
    payload = {
        "name": cname, "score": score, "percent": pct,
        "online": len(on), "total": len(present), "errored": len(er),
        "processes": [{
            "name": by[p]["name"],
            "script": by[p]["pm2_env"].get("pm_exec_path"),
            "interpreter": by[p]["pm2_env"].get("exec_interpreter"),
            "max_mem": by[p]["pm2_env"].get("max_memory_restart"),
            "status": by[p]["pm2_env"]["status"],
            "restarts": by[p]["pm2_env"].get("restart_time",0),
            "mem_mb": ((by[p]["pm2_env"].get("monit",{}) or {}).get("memory",0) or 0)//(1024*1024)
        } for p in present],
    }
    (dump/f"{cname}.json").write_text(json.dumps(payload, indent=2, ensure_ascii=False))
    summary[cname] = {"score":score,"pct":pct,"online":len(on),"total":len(present),"err":len(er)}

# загальний
total_on = sum(v["online"] for v in summary.values())
total_pr = sum(v["total"] for v in summary.values())
overall_pct = round(100*total_on/total_pr,1) if total_pr else 0
(dump/"index.json").write_text(json.dumps({
    "ts": dump.name.replace("comp_",""),
    "overall_pct": overall_pct,
    "online": f"{total_on}/{total_pr}",
    "components": summary
}, indent=2, ensure_ascii=False))
print(json.dumps({"overall":overall_pct,"components":summary}))
PY

# ротація: 12 останніх (1 година при 5 хв)
ls -1dt "$CYBRA"/dumps/components/comp_*/ 2>/dev/null | tail -n +13 | xargs -r rm -rf
ln -sfn "comp_$TS" "$CYBRA/dumps/components/latest"

# короткий вивід
ONLINE=$(jq -r '.online' "$D/index.json" 2>/dev/null)
PCT=$(jq -r '.overall_pct' "$D/index.json" 2>/dev/null)
echo "[$(date +%H:%M:%S)] comp_$TS ${ONLINE}online ${PCT}%"
jq -r '.components | to_entries[] | "  \(.key): \(.value.online)/\(.value.total) score=\(.value.score)"' "$D/index.json" 2>/dev/null
