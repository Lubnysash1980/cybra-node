#!/usr/bin/env python3
import json, os, subprocess, time
from pathlib import Path
from datetime import datetime
ROOT=Path(os.environ.get("CYBRA",Path.home()/"CYBRA"))
MAN=ROOT/"state"/"manifest.json"; LOG=ROOT/"logs"/"reaper.log"; LOG.parent.mkdir(parents=True,exist_ok=True)
def log(m):
    l=f"[{datetime.now():%F %T}] {m}"; LOG.open("a").write(l+"\n"); print(l)
def sh(c,t=30):
    try: return subprocess.check_output(c,shell=True,text=True,timeout=t,stderr=subprocess.DEVNULL).strip()
    except: return ""
def cq():
    q=ROOT/"queue"/"parliament"; n=0
    if not q.exists(): return 0
    for f in q.glob("*.json"):
        try:
            if time.time()-f.stat().st_mtime>300: f.unlink(); n+=1
        except: pass
    fs=sorted(q.glob("*.json"),key=lambda f:f.stat().st_mtime,reverse=True)
    for f in fs[100:]:
        try: f.unlink(); n+=1
        except: pass
    return n
def clog():
    d=Path.home()/".pm2"/"logs"; n=f=0
    if not d.exists(): return 0,0
    for x in d.glob("*.log"):
        try:
            s=x.stat().st_size
            if s>10*1024*1024:
                with x.open("rb") as fh: fh.seek(-1024*1024,2); t=fh.read()
                x.write_bytes(t); f+=(s-1024*1024)//(1024*1024); n+=1
        except: pass
    return n,f
def cycle():
    if not MAN.exists(): return
    m=json.loads(MAN.read_text()); r=m.get("resources",{})
    ram=r.get("ram_avail_pct",100); disk=r.get("disk_mb",999999); qn=r.get("queue_files",0)
    acts=[]
    if qn>500: acts.append(f"queue -{cq()}")
    if disk<5000: acts.append(f"logs {clog()}")
    if ram<15: acts.append(f"queue -{cq()}")
    if acts: log(f"ram={ram}% disk={disk}MB q={qn} → {', '.join(acts)}")
if __name__=="__main__": cycle()
