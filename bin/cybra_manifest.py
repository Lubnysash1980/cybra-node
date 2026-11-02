#!/usr/bin/env python3
import json, os, subprocess, time
from pathlib import Path
from datetime import datetime, timezone
ROOT = Path(os.environ.get("CYBRA", Path.home()/"CYBRA"))
OUT = ROOT/"state"/"manifest.json"; OUT.parent.mkdir(parents=True, exist_ok=True)
def sh(c,t=5):
    try: return subprocess.check_output(c,shell=True,text=True,timeout=t,stderr=subprocess.DEVNULL).strip()
    except: return ""
def main():
    try: procs = json.loads(subprocess.check_output(["pm2","jlist"],text=True,timeout=10))
    except: procs=[]
    fm=[l for l in sh("free -m").splitlines() if l.startswith("Mem:")]
    ram_total=ram_avail=0
    if fm:
        p=fm[0].split(); ram_total,ram_avail=int(p[1]),int(p[-1])
    df=sh(f"df -Pk {ROOT} | tail -1").split()
    disk=int(df[3])//1024 if len(df)>=4 and df[3].isdigit() else 0
    q=ROOT/"queue"/"parliament"; qn=len(list(q.glob("*.json"))) if q.exists() else 0
    items={}; c={"green":0,"yellow":0,"red":0,"black":0}; ts=0
    for p in procs:
        n=p["name"]; e=p["pm2_env"]; st=e.get("status")
        lim=str(e.get("max_memory_restart")); rst=e.get("restart_time",0) or 0
        mem=(e.get("monit",{}) or {}).get("memory",0) or 0; mb=mem//(1024*1024)
        if st!="online": col,sc,r="black",0,"dead"
        elif lim not in ("65M","68157440"): col,sc,r="red",25,f"limit={lim}"
        elif rst>200: col,sc,r="red",40,f"{rst}↺"
        elif mb>60: col,sc,r="yellow",70,f"{mb}MB"
        else: col,sc,r="green",100,"ok"
        c[col]+=1; ts+=sc
        items[n]={"color":col,"score":sc,"reason":r,"status":st,"restarts":rst,"mem_limit":lim}
    tot=len(procs) or 1; pct=round(ts/tot,1)
    rp=round(100*ram_avail/ram_total,1) if ram_total else 0
    rc="green" if rp>=25 else ("yellow" if rp>=15 else ("red" if rp>=10 else "black"))
    if disk<2000: rc="black"
    if qn>500: rc="red" if rc=="green" else rc
    ov="black" if c["black"] else ("red" if c["red"] else ("yellow" if c["yellow"] else "green"))
    m={"ts":time.time(),"iso":datetime.now(timezone.utc).isoformat(),
       "overall":{"percent":pct,"color":ov},"colors":c,"items":items,
       "resources":{"ram_total_mb":ram_total,"ram_avail_mb":ram_avail,"ram_avail_pct":rp,"disk_mb":disk,"queue_files":qn,"color":rc},
       "needs_cleanup": rp<15 or disk<5000 or qn>500,
       "needs_throttle": rp<10}
    OUT.write_text(json.dumps(m,indent=2,ensure_ascii=False))
    sh(f"redis-cli SET cybra:manifest '{json.dumps(m)}' >/dev/null")
    sh(f"redis-cli SET cybra:overall_color {ov} >/dev/null")
    print(f"{ov.upper():6s} {pct}% | g{c['green']} y{c['yellow']} r{c['red']} b{c['black']} | ram {rp}% disk {disk}MB q{qn}")
if __name__=="__main__": main()
