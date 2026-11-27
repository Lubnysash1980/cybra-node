#!/usr/bin/env python3
"""Read-only CYBRA evolution dashboard. No PM2 or production changes."""
from __future__ import annotations
import json, os, time, hashlib, subprocess
from pathlib import Path
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT = Path(os.environ.get("CYBRA_ROOT", Path(__file__).resolve().parents[1])).expanduser().resolve()
DATA = Path(os.environ.get("CYBRA_EVOLUTION_DATA", ROOT / "state" / "evolution_dashboard")).expanduser()
BASELINE = DATA / "baseline.json"
HISTORY = DATA / "history.jsonl"
PORT = int(os.environ.get("CYBRA_EVOLUTION_PORT", "8765"))
TARGET_MODULES = 500
THRESHOLD = 3.0
IGNORE = {".git", "__pycache__", ".venv", "node_modules", ".pytest_cache", "evolution_dashboard"}
EXTENSIONS = {".py", ".js", ".mjs", ".cjs", ".ts", ".sh", ".json", ".toml", ".yaml", ".yml", ".html", ".css", ".md", ".sol"}

def scan():
    files, total = [], 0
    for p in ROOT.rglob("*"):
        try:
            if not p.is_file() or any(part in IGNORE for part in p.relative_to(ROOT).parts):
                continue
            if p.suffix.lower() not in EXTENSIONS:
                continue
            size = p.stat().st_size
            total += size
            files.append({"path": str(p.relative_to(ROOT)), "bytes": size, "mtime": p.stat().st_mtime})
        except (OSError, ValueError):
            continue
    files.sort(key=lambda x: x["path"])
    return files, total

def load_json(path, default):
    try: return json.loads(path.read_text())
    except (OSError, ValueError): return default

def save_baseline(files, total):
    DATA.mkdir(parents=True, exist_ok=True)
    payload = {"created_at": datetime.now(timezone.utc).isoformat(), "root": str(ROOT),
               "bytes": total, "files": {x["path"]: x["bytes"] for x in files}}
    BASELINE.write_text(json.dumps(payload, indent=2))
    return payload

def collect():
    files, total = scan()
    baseline = load_json(BASELINE, None)
    if baseline is None or baseline.get("root") != str(ROOT):
        baseline = save_baseline(files, total)
    base_bytes = max(int(baseline.get("bytes", 0)), 1)
    evolution = (total - base_bytes) / base_bytes * 100
    previous = load_json(DATA / "last.json", {})
    now = datetime.now(timezone.utc).isoformat()
    new_paths = sorted(set(x["path"] for x in files) - set(baseline.get("files", {})))
    changed = sum(1 for x in files if x["path"] in baseline.get("files", {}) and
                  x["bytes"] != baseline["files"][x["path"]])
    module_paths = [x for x in files if Path(x["path"]).name.startswith("module_")]
    pm2 = {"available": False, "online": None, "total": None}
    try:
        out = subprocess.run(["pm2", "jlist"], capture_output=True, text=True, timeout=2)
        if out.returncode == 0:
            rows = json.loads(out.stdout)
            pm2 = {"available": True, "online": sum(1 for x in rows if x.get("pm2_env", {}).get("status") == "online"),
                   "total": len(rows)}
    except Exception: pass
    if evolution >= THRESHOLD and not previous.get("threshold_reached"):
        DATA.mkdir(parents=True, exist_ok=True)
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        snapshot = DATA / f"evolution_snapshot_{stamp}.json"
        snapshot.write_text(json.dumps({"at": now, "bytes": total, "evolution_pct": round(evolution, 3),
                                        "files": files}, indent=2))
        with HISTORY.open("a") as f:
            f.write(json.dumps({"at": now, "event": "threshold_3pct", "evolution_pct": evolution,
                                "snapshot": str(snapshot)}) + "\n")
    state = {"at": now, "root": str(ROOT), "bytes": total, "kilobytes": round(total/1024, 2),
             "baseline_bytes": base_bytes, "evolution_pct": round(evolution, 3),
             "threshold_reached": evolution >= THRESHOLD, "new_files": len(new_paths),
             "changed_files": changed, "files": len(files), "modules_detected": len(module_paths),
             "module_target": TARGET_MODULES, "module_pct": round(min(100, len(module_paths)/TARGET_MODULES*100), 2),
             "auto_creation_pct": round(len(new_paths)/max(len(files),1)*100, 2),
             "health_pct": None, "health_label": "НЕ ВИМІРЮЄТЬСЯ — потрібні health-check модулів",
             "pm2": pm2, "restart_mode": "MANUAL_ONLY", "new_paths": new_paths[:100]}
    DATA.mkdir(parents=True, exist_ok=True)
    (DATA / "last.json").write_text(json.dumps({"threshold_reached": state["threshold_reached"]}))
    with HISTORY.open("a") as f: f.write(json.dumps(state) + "\n")
    state["history"] = []
    try:
        for line in HISTORY.read_text().splitlines()[-240:]:
            row = json.loads(line)
            if "evolution_pct" in row: state["history"].append({"at": row["at"], "evolution_pct": round(row["evolution_pct"],3)})
    except (OSError, ValueError): pass
    return state

PAGE = r"""<!doctype html><html lang="uk"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CYBRA Evolution</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#090f19;color:#e8eef8;font:15px system-ui}main{max-width:1100px;margin:auto;padding:24px}.top{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}.muted{color:#93a4ba}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:14px;margin:20px 0}.card{background:#121d2b;border:1px solid #26374c;border-radius:14px;padding:18px}.value{font-size:28px;font-weight:700;margin:8px 0}.bar{height:14px;background:#273548;border-radius:20px;overflow:hidden}.fill{height:100%;width:0;background:#21c777;transition:width .3s}.yellow{background:#e8b83d}.red{background:#e05252}.green{color:#36d68b}.warn{color:#e8b83d}.bad{color:#ff7777}canvas{width:100%;height:220px;background:#0d1724;border-radius:10px}.pill{padding:5px 9px;border-radius:20px;background:#26374c}.modules{display:flex;flex-wrap:wrap;gap:5px}.dot{width:12px;height:12px;border-radius:3px;background:#59677a}.foot{font-size:12px;color:#93a4ba;line-height:1.6}button{background:#20334a;color:#fff;border:1px solid #45617f;padding:9px 12px;border-radius:8px}
</style><main><div class="top"><div><h1>CYBRA · EVOLUTION CONTROL</h1><div class="muted" id="root">Завантаження…</div></div><div><span class="pill" id="status">ЗБІР ДАНИХ</span> <button onclick="refresh()">Оновити</button></div></div>
<div class="grid"><section class="card"><div class="muted">Еволюція від базового обсягу</div><div class="value" id="evo">—</div><div class="bar"><div class="fill" id="evoBar"></div></div><p class="foot">Поріг події: +3% від baseline у байтах</p></section>
<section class="card"><div class="muted">Модулі</div><div class="value" id="mods">—</div><div class="bar"><div class="fill" id="modBar"></div></div><p class="foot">Ціль: 500; рахуємо знайдені файли module_*</p></section>
<section class="card"><div class="muted">Автостворення</div><div class="value" id="creation">—</div><p class="foot" id="created">Нових файлів: —</p></section>
<section class="card"><div class="muted">Обсяг коду</div><div class="value" id="size">—</div><p class="foot" id="files">Файлів: —</p></section>
<section class="card"><div class="muted">Здоров’я</div><div class="value warn" id="health">НЕ ВИМІРЮЄТЬСdiv><p class="foot">Не підміняємо реальний health-check вигаданим відсотком.</p></section>
<section class="card"><div class="muted">PM2</div><div class="value" id="pm2">—</div><p class="foot" id="restart">Рестарт: лише вручну</p></section></div>
<section class="card"><h2>Еволюція за часом</h2><canvas id="chart" width="1000" height="220"></canvas><p class="foot" id="updated"></p></section>
<section class="card"><h2>500 модулів · індикатори</h2><div class="modules" id="dots"></div><p class="foot">Зелений — знайдений файл модуля; жовтий — резерв до цілі; червоний — помилка health-check (поки не підключений).</p></section>
<section class="card"><h2>Правило +3%</h2><p id="rule">При досягненні +3% створюється JSON-знімок стану та запис у журналі. Автоматичний рестарт вимкнений: MANUAL_ONLY.</p><p class="foot">Деградація (від’ємна зміна) відображається окремо від зростання. Зменшення обсягу не означає автоматично поломку.</p></section>
</main><script>
async function refresh(){try{let r=await fetch('/api/state',{cache:'no-store'}),d=await r.json();document.getElementById('root').textContent=d.root;let e=d.evolution_pct;document.getElementById('evo').textContent=(e>0?'+':'')+e+'%';let eb=document.getElementById('evoBar');eb.style.width=Math.min(100,Math.abs(e)/3*100)+'%';eb.className='fill '+(e>=3?'green':e<0?'red':'yellow');document.getElementById('mods').textContent=d.modules_detected+' / 500';document.getElementById('modBar').style.width=d.module_pct+'%';document.getElementById('creation').textContent=d.auto_creation_pct+'%';document.getElementById('created').textContent='Нових файлів: '+d.new_files+' · змінених: '+d.changed_files;document.getElementById('size').textContent=d.kilobytes.toLocaleString('uk-UA')+' KB';document.getElementById('files').textContent='Файлів: '+d.files+' · baseline: '+d.baseline_bytes+' B';document.getElementById('health').textContent='НЕ ВИМІРЮЄТЬСЯ';document.getElementById('pm2').textContent=d.pm2.available?d.pm2.online+' online / '+d.pm2.total:'не підключено';document.getElementById('restart').textContent='Рестарт: '+d.restart_mode;document.getElementById('status').textContent=e>=3?'ПОРОГ +3%':e<0?'ДЕГРАДАЦІЯ ОБСЯГУ':'МОНІТОРИНГ';document.getElementById('status').className='pill '+(e>=3?'green':e<0?'bad':'warn');document.getElementById('rule').textContent=e>=3?'Поріг досягнуто. JSON-знімок збережено; рестарт не запускався.':'До порогу +3%: '+(3-e).toFixed(3)+' процентного пункту.';document.getElementById('updated').textContent='Оновлено: '+d.at+' · baseline: '+d.baseline_bytes+' B';let dots=document.getElementById('dots');dots.innerHTML='';for(let i=0;i<500;i++){let s=document.createElement('i');s.className='dot';if(i<d.modules_detected)s.style.background='#21c777';else if(i<500)s.style.background='#b88a32';dots.appendChild(s)}draw(d.history||[])}catch(e){document.getElementById('status').textContent='ПОМИЛКА API'}}
function draw(h){let c=document.getElementById('chart'),x=c.getContext('2d'),w=c.width,H=c.height;x.clearRect(0,0,w,H);x.strokeStyle='#30445c';x.beginPath();x.moveTo(35,15);x.lineTo(35,H-25);x.lineTo(w-10,H-25);x.stroke();if(!h.length)return;let vals=h.map(v=>v.evolution_pct),min=Math.min(-1,...vals),max=Math.max(3,...vals),range=max-min||1;x.strokeStyle='#25d18a';x.lineWidth=3;x.beginPath();h.forEach((v,i)=>{let px=35+i*(w-55)/Math.max(1,h.length-1),py=15+(max-v.evolution_pct)*(H-40)/range;i?x.lineTo(px,py):x.moveTo(px,py)});x.stroke();let ty=15+(max-3)*(H-40)/range;x.strokeStyle='#d8ad42';x.setLineDash([6,5]);x.beginPath();x.moveTo(35,ty);x.lineTo(w-10,ty);x.stroke();x.setLineDash([]);x.fillStyle='#9aabc0';x.fillText(' +3% ',w-60,ty-5)}
refresh();setInterval(refresh,10000);
</script></html>"""

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        route = urlparse(self.path).path
        if route == "/":
            body = PAGE.encode()
            self.send_response(200); self.send_header("Content-Type","text/html; charset=utf-8"); self.send_header("Content-Length",str(len(body))); self.end_headers(); self.wfile.write(body)
        elif route == "/api/state":
            body = json.dumps(collect(), ensure_ascii=False).encode()
            self.send_response(200); self.send_header("Content-Type","application/json; charset=utf-8"); self.send_header("Cache-Control","no-store"); self.send_header("Content-Length",str(len(body))); self.end_headers(); self.wfile.write(body)
        elif route == "/health":
            body = b'{"ok":true,"mode":"read-only"}'
            self.send_response(200); self.send_header("Content-Type","application/json"); self.end_headers(); self.wfile.write(body)
        else: self.send_error(404)
    def log_message(self, fmt, *args): print("[%s] %s"%(self.log_date_time_string(),fmt%args))

if __name__ == "__main__":
    print("CYBRA Evolution Dashboard — read-only")
    print("ROOT:", ROOT)
    print("URL: http://127.0.0.1:%s/" % PORT)
    print("Restart policy: MANUAL_ONLY")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
