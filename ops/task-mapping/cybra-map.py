#!/usr/bin/env python3
"""CYBRA BAR task-map CLI. Safe local JSON/NDJSON writer; no shell execution."""
import argparse, json, os, sys, time, uuid, fcntl
from pathlib import Path
ROOT=Path(os.environ.get("CYBRA_ROOT",Path(__file__).resolve().parents[2])).resolve()
BASE=ROOT/"ops"/"task-mapping"
TASKS=BASE/"tasks.json"; EVENTS=BASE/"events.ndjson"
def read(p,default):
    try: return json.loads(p.read_text())
    except FileNotFoundError: return default
def atomic(p,obj):
    p.parent.mkdir(parents=True,exist_ok=True)
    tmp=p.with_suffix(p.suffix+".tmp")
    tmp.write_text(json.dumps(obj,ensure_ascii=False,indent=2)+"\n")
    os.replace(tmp,p)
def log(event):
    BASE.mkdir(parents=True,exist_ok=True)
    with (BASE/"events.lock").open("w") as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        with EVENTS.open("a") as f: f.write(json.dumps(event,ensure_ascii=False)+"\n")
def classify(status,progress,evidence=None):
    evidence = evidence or []
    if status in ("failed","blocked"): return "red"
    if status=="done" and progress==100 and evidence: return "green"
    if status=="planned" and progress==0 and not evidence: return "not_checked"
    if status=="degraded": return "yellow" if progress>=30 else "red"
    if status=="in_progress": return "yellow" if progress>=30 else "red"
    if progress>=30 and progress<100: return "yellow"
    if progress<30 and (status not in ("planned",) or evidence): return "red"
    return "not_checked"
def main():
    ap=argparse.ArgumentParser(prog="cybra-map")
    sub=ap.add_subparsers(dest="cmd",required=True)
    p=sub.add_parser("add"); p.add_argument("id"); p.add_argument("title"); p.add_argument("--executor",action="append",default=[]); p.add_argument("--acceptance",action="append",default=[])
    p=sub.add_parser("update"); p.add_argument("id"); p.add_argument("--status",choices=["planned","in_progress","degraded","blocked","failed","done"]); p.add_argument("--progress",type=int); p.add_argument("--note",default=""); p.add_argument("--executor",action="append")
    p=sub.add_parser("event"); p.add_argument("id"); p.add_argument("message"); p.add_argument("--executor",default="human"); p.add_argument("--kind",default="note")
    sub.add_parser("list"); sub.add_parser("validate")
    a=ap.parse_args(); data=read(TASKS,{"schemaVersion":1,"project":"CYBRA BAR","tasks":[]})
    if a.cmd=="add":
        if any(t["id"]==a.id for t in data["tasks"]): raise SystemExit("TASK_EXISTS")
        t={"id":a.id,"title":a.title,"status":"planned","progress":0,"level":"not_checked","executors":a.executor,"acceptance":a.acceptance,"evidence":[],"dependencies":[]}
        data["tasks"].append(t); atomic(TASKS,data)
        log({"id":str(uuid.uuid4()),"task":a.id,"kind":"created","executor":"human","message":"Task created","ts":time.time()})
        print(json.dumps(t,ensure_ascii=False,indent=2))
    elif a.cmd=="update":
        t=next((x for x in data["tasks"] if x["id"]==a.id),None)
        if not t: raise SystemExit("TASK_NOT_FOUND")
        if a.status: t["status"]=a.status
        if a.progress is not None:
            if not 0<=a.progress<=100: raise SystemExit("PROGRESS_OUT_OF_RANGE")
            t["progress"]=a.progress
        if a.executor is not None: t["executors"]=sorted(set(t.get("executors",[])+a.executor))
        t["level"]=classify(t["status"],t["progress"],t.get("evidence"))
        if t["level"]=="green" and not t.get("evidence"): raise SystemExit("GREEN_REQUIRES_EVIDENCE")
        atomic(TASKS,data)
        log({"id":str(uuid.uuid4()),"task":a.id,"kind":"status_update","executor":"cli","message":a.note,"status":t["status"],"progress":t["progress"],"level":t["level"],"ts":time.time()})
        print(json.dumps(t,ensure_ascii=False,indent=2))
    elif a.cmd=="event":
        if not any(t["id"]==a.id for t in data["tasks"]): raise SystemExit("TASK_NOT_FOUND")
        log({"id":str(uuid.uuid4()),"task":a.id,"kind":a.kind,"executor":a.executor,"message":a.message,"ts":time.time()}); print("EVENT_RECORDED")
    elif a.cmd=="list": print(json.dumps(data,ensure_ascii=False,indent=2))
    elif a.cmd=="validate":
        ids=[t["id"] for t in data["tasks"]]
        assert len(ids)==len(set(ids)),"duplicate task IDs"
        for t in data["tasks"]:
            assert 0<=t["progress"]<=100
            assert t["level"] in ("green","yellow","red","not_checked")
            if t["level"]=="yellow": assert t["progress"]>=30 and t["progress"]<100,t["id"]
            if t["level"]=="red" and t["status"] not in ("failed","blocked"): assert t["progress"]<30,t["id"]
            if t["level"]=="green": assert t["status"]=="done" and t["progress"]==100 and t.get("evidence"),t["id"]
        print("TASK_MAP_OK",len(ids))
if __name__=="__main__": main()
