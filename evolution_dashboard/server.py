#!/usr/bin/env python3
"""CYBRA Evolution Dashboard: local-only, read-only monitor."""
from __future__ import annotations
import json, os, subprocess
from pathlib import Path
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT = Path(os.environ.get("CYBRA_ROOT", Path(__file__).resolve().parents[1])).expanduser().resolve()
DATA = Path(os.environ.get("CYBRA_EVOLUTION_DATA", ROOT / "state" / "evolution_dashboard")).expanduser()
BASELINE = DATA / "baseline.json"
HISTORY = DATA / "history.jsonl"
SEEN = DATA / "seen.json"
LAST = DATA / "last.json"
PORT = int(os.environ.get("CYBRA_EVOLUTION_PORT", "8765"))
TARGET_MODULES = 500
THRESHOLD = 3.0
EXTENSIONS = {".py", ".js", ".mjs", ".cjs", ".ts", ".sh", ".json", ".toml", ".yaml", ".yml", ".html", ".css", ".md", ".sol"}
IGNORE = {".git", "__pycache__", ".venv", "node_modules", ".pytest_cache", "evolution_dashboard"}

def now():
    return datetime.now(timezone.utc).isoformat()

def load_json(path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError, TypeError):
        return default

def scan():
    rows, total = [], 0
    for p in ROOT.rglob("*"):
        try:
            rel = p.relative_to(ROOT)
            if not p.is_file() or any(part in IGNORE for part in rel.parts):
                continue
            if rel.parts[:2] == ("state", "evolution_dashboard"):
                continue
            if p.suffix.lower() not in EXTENSIONS:
                continue
            size = p.stat().st_size
            rows.append({"path": rel.as_posix(), "bytes": size})
            total += size
        except (OSError, ValueError):
            continue
    rows.sort(key=lambda x: x["path"])
    return rows, total

def module_inventory():
    registry_path = ROOT / "@cybra" / "index.json"
    registry = load_json(registry_path, {})
    names = registry.get("modules", []) if isinstance(registry, dict) else []
    inventory = []
    for item in names:
        name = item.get("name") if isinstance(item, dict) else None
        if not isinstance(name, str) or not name.startswith("module_"):
            continue
        module_path = ROOT / "modules" / name
        present = module_path.exists()
        approved = (ROOT / "evolution" / (name + ".approved")).is_file()
        inventory.append({
            "name": name,
            "present": present,
            "approved": approved,
            "status": "red" if not present else "yellow",
            "status_label": "ВІДСУТНІЙ" if not present else ("Є APPROVED, health не перевірено" if approved else "ЗНАЙДЕНИЙ, health не перевірено")
        })
    inventory.sort(key=lambda x: x["name"])
    return inventory, bool(names)

def pm2_readonly():
    try:
        p = subprocess.run(["pm2", "jlist"], capture_output=True, text=True, timeout=2, check=False)
        if p.returncode != 0:
            return {"available": False, "online": None, "total": None}
        rows = json.loads(p.stdout)
        return {"available": True,
                "online": sum(1 for x in rows if x.get("pm2_env", {}).get("status") == "online"),
                "total": len(rows)}
    except Exception:
        return {"available": False, "online": None, "total": None}

def append_event(event):
    DATA.mkdir(parents=True, exist_ok=True)
    with HISTORY.open("a", encoding="utf-8") as f:
        f.write(json.dumps(event, ensure_ascii=False) + "\n")

def daily_history():
    by_day = {}
    try:
        for line in HISTORY.read_text(encoding="utf-8").splitlines():
            try:
                row = json.loads(line)
                stamp = row.get("at", "")
                day = stamp[:10]
                if not day:
                    continue
                entry = by_day.setdefault(day, {"day": day, "evolution_pct": None, "created_files": 0})
                if "evolution_pct" in row:
                    entry["evolution_pct"] = row["evolution_pct"]
                if row.get("event") == "file_created":
                    entry["created_files"] += 1
            except ValueError:
                continue
    except OSError:
        pass
    return list(by_day.values())[-90:]

def collect():
    files, total = scan()
    baseline = load_json(BASELINE, None)
    if not isinstance(baseline, dict) or baseline.get("root") != str(ROOT):
        DATA.mkdir(parents=True, exist_ok=True)
        baseline = {"created_at": now(), "root": str(ROOT), "bytes": total,
                    "files": {x["path"]: x["bytes"] for x in files}}
        BASELINE.write_text(json.dumps(baseline, ensure_ascii=False, indent=2), encoding="utf-8")
    base_bytes = max(int(baseline.get("bytes", 0)), 1)
    evolution = (total - base_bytes) / base_bytes * 100
    baseline_files = baseline.get("files", {})
    current_paths = {x["path"] for x in files}
    baseline_paths = set(baseline_files)
    new_paths = sorted(current_paths - baseline_paths)
    changed = sum(1 for x in files if x["path"] in baseline_files and x["bytes"] != baseline_files[x["path"]])

    seen_data = load_json(SEEN, None)
    if seen_data is None:
        seen = set(baseline_paths)
    else:
        seen = set(seen_data)
    fresh = sorted(current_paths - seen)
    for path in fresh:
        append_event({"at": now(), "event": "file_created", "path": path})
    DATA.mkdir(parents=True, exist_ok=True)
    SEEN.write_text(json.dumps(sorted(current_paths)), encoding="utf-8")

    previous = load_json(LAST, {})
    reached = evolution >= THRESHOLD
    snapshot_path = previous.get("last_snapshot")
    if reached and not previous.get("threshold_reached"):
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        snap = DATA / ("evolution_snapshot_" + stamp + ".json")
        snap.write_text(json.dumps({"at": now(), "bytes": total,
                                    "evolution_pct": round(evolution, 3),
                                    "files": files}, ensure_ascii=False, indent=2), encoding="utf-8")
        snapshot_path = str(snap)
        append_event({"at": now(), "event": "threshold_3pct",
                      "evolution_pct": round(evolution, 3), "snapshot": snap.name})
    LAST.write_text(json.dumps({"threshold_reached": reached, "last_snapshot": snapshot_path}), encoding="utf-8")

    modules, registry_ok = module_inventory()
    present = sum(1 for m in modules if m["present"])
    missing = len(modules) - present
    pm2 = pm2_readonly()
    state = {
        "at": now(), "root": str(ROOT), "bytes": total, "kilobytes": round(total / 1024, 2),
        "baseline_bytes": base_bytes, "evolution_pct": round(evolution, 3),
        "threshold_pct": THRESHOLD, "threshold_reached": reached,
        "last_dump": snapshot_path, "new_files": len(new_paths), "changed_files": changed,
        "files": len(files), "modules_detected": len(modules), "modules_present": present,
        "modules_missing": missing, "module_target": TARGET_MODULES,
        "module_pct": round(min(100, len(modules) / TARGET_MODULES * 100), 2),
        "auto_creation_pct": round(len(new_paths) / max(len(files), 1) * 100, 2),
        "health_pct": None, "health_label": "НЕ ВИМІРЮЄТЬСЯ — runtime health-check не підключений",
        "registry_available": registry_ok, "module_inventory": modules,
        "pm2": pm2, "restart_mode": "MANUAL_ONLY",
        "restart_note": "Автоперезапуск вимкнений: немає підтвердженого health-gate та rollback."
    }
    append_event({"at": state["at"], "event": "sample", "evolution_pct": state["evolution_pct"]})
    state["history"] = daily_history()
    return state

PAGE = r"""<!doctype html><html lang="uk"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>CYBRA NEURO Evolution</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#080e18;color:#e8eef8;font:15px system-ui}main{max-width:1180px;margin:auto;padding:20px}.top{display:flex;justify-content:space-between;align-items:center;gap:12px;flex-wrap:wrap}.muted,.note{color:#91a3b9}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:12px;margin:18px 0}.card{background:#121d2b;border:1px solid #293a50;border-radius:14px;padding:16px;margin-bottom:14px}.value{font-size:27px;font-weight:750;margin:8px 0}.bar{height:13px;background:#29384a;border-radius:20px;overflow:hidden}.fill{height:100%;width:0;background:#e5b43c;transition:width .3s}.fill.green{background:#20c77a}.fill.red{background:#e05252}.pill{padding:6px 10px;border-radius:20px;background:#27384c}.green{color:#36d68b}.yellow{color:#e5b43c}.red{color:#ff7777}.dots{display:grid;grid-template-columns:repeat(25,12px);gap:5px}.dot{width:12px;height:12px;border-radius:3px;background:#3b4859}.dot.yellow{background:#d6a83c}.dot.green{background:#21c77a}.dot.red{background:#e05252}canvas{width:100%;height:230px;background:#0b1522;border-radius:10px}button{background:#20334a;color:#fff;border:1px solid #45617f;padding:9px 13px;border-radius:8px}.legend{display:flex;gap:15px;flex-wrap:wrap;font-size:13px}.legend span:before{content:"";display:inline-block;width:10px;height:10px;border-radius:3px;margin-right:6px}.lg{background:#21c77a}.ly{background:#d6a83c}.lr{background:#e05252}.ls{background:#3b4859}.module-list{max-height:260px;overflow:auto;font:12px ui-monospace,monospace}.module-row{display:flex;justify-content:space-between;padding:5px;border-bottom:1px solid #26364a}.note{font-size:12px;line-height:1.6}
</style><main>
<div class="top"><div><h1>CYBRA NEURO · EVOLUTION CONTROL</h1><div class="muted" id="root">Завантаження…</div></div><div><span class="pill" id="status">ЗБІР ДАНИХ</span> <button onclick="refresh()">ОНОВИТИ</button></div></div>
<div class="grid">
<section class="card"><div class="muted">Еволюція від baseline</div><div class="value" id="evo">—</div><div class="bar"><div class="fill" id="evoBar"></div></div><p class="note">Поріг автодампу: +3% обсягу файлів у байтах</p></section>
<section class="card"><div class="muted">Реєстр модулів</div><div class="value" id="mods">—</div><div class="bar"><div class="fill" id="modBar"></div></div><p class="note" id="modnote">Цільова кількість: 500</p></section>
<section class="card"><div class="muted">Створення після baseline</div><div class="value" id="creation">—</div><p class="note" id="created">Нових файлів: —</p></section>
<section class="card"><div class="muted">Обсяг відстежуваних файлів</div><div class="value" id="size">—</div><p class="note" id="files">Файлів: —</p></section>
<section class="card"><div class="muted">Здоров’я</div><div class="value yellow" id="health">НЕ ВИМІРЮЄТЬСЯ</div><p class="note">Відсоток з’явиться після підключення справжніх health-check.</p></section>
<section class="card"><div class="muted">PM2 · тільки читання</div><div class="value" id="pm2">—</div><p class="note" id="restart">Рестарт: MANUAL_ONLY</p></section>
</div>
<section class="card"><h2>Еволюція та створення по днях</h2><canvas id="chart" width="1100" height="230"></canvas><p class="note" id="updated"></p></section>
<section class="card"><h2>Індикатори 500 модулів</h2><div class="legend"><span><i class="lg"></i>Перевірений зелений</span><span><i class="ly"></i>Знайдений, health невідомий</span><span><i class="lr"></i>Відсутній</span><span><i class="ls"></i>Ще не зареєстрований</span></div><div class="dots" id="dots" style="margin-top:14px"></div><p class="note" id="registry"></p><div class="module-list" id="moduleList"></div></section>
<section class="card"><h2>Правило +3%</h2><p id="rule">При +3% формується JSON-дамп. Автоперезапуск поки вимкнений до перевірки health-gate та rollback.</p><p class="note" id="dump"></p><p class="note">Від’ємна зміна обсягу позначається як деградація розміру, але не прирівнюється автоматично до несправності. Зелений статус можливий лише після реального health-check.</p></section>
</main><script>
async function refresh(){try{const r=await fetch('/api/state',{cache:'no-store'});const d=await r.json();const e=d.evolution_pct;document.getElementById('root').textContent=d.root;document.getElementById('evo').textContent=(e>0?'+':'')+e+'%';const eb=document.getElementById('evoBar');eb.style.width=Math.min(100,Math.abs(e)/3*100)+'%';eb.className='fill '+(e>=3?'green':e<0?'red':'');document.getElementById('mods').textContent=d.modules_detected+' / '+d.module_target;document.getElementById('modBar').style.width=d.module_pct+'%';document.getElementById('modnote').textContent='У реєстрі: '+d.modules_detected+' · на диску: '+d.modules_present+' · відсутні: '+d.modules_missing;document.getElementById('creation').textContent=d.auto_creation_pct+'%';document.getElementById('created').textContent='Нових файлів: '+d.new_files+' · змінених: '+d.changed_files;document.getElementById('size').textContent=d.kilobytes.toLocaleString('uk-UA')+' KB';document.getElementById('files').textContent='Файлів: '+d.files+' · baseline: '+d.baseline_bytes+' B';document.getElementById('health').textContent='НЕ ВИМІРЮЄТЬСЯ';document.getElementById('pm2').textContent=d.pm2.available?d.pm2.online+' online / '+d.pm2.total:'не підключено';document.getElementById('restart').textContent='Рестарт: '+d.restart_mode;const st=document.getElementById('status');st.textContent=e>=3?'ДАМП +3%':e<0?'МІНУС ОБСЯГУ':'МОНІТОРИНГ';st.className='pill '+(e>=3?'green':e<0?'red':'yellow');document.getElementById('rule').textContent=e>=3?'Поріг досягнуто: JSON-дамп сформовано. Перезапуск не запускався.':(e<0?'Зафіксовано зменшення обсягу на '+Math.abs(e).toFixed(3)+'%.':'До порогу +3% залишилося '+(3-e).toFixed(3)+' п.п.');document.getElementById('dump').textContent='Останній дамп: '+(d.last_dump||'ще не створювався')+' · '+d.restart_note;document.getElementById('updated').textContent='Оновлено: '+d.at+' · baseline: '+d.baseline_bytes+' B';document.getElementById('registry').textContent=d.registry_available?'Джерело кількості: @cybra/index.json. Зелених: 0 — runtime health-check ще не підключено.':'Реєстр @cybra/index.json не знайдено; перевірте checkout.';const dots=document.getElementById('dots');dots.replaceChildren();for(let i=0;i<500;i++){const el=document.createElement('i');el.className='dot';if(i<d.module_inventory.length){const m=d.module_inventory[i];el.className='dot '+m.status;el.title=m.name+' — '+m.status_label}else{el.title='Модуль ще не внесений до реєстру'}dots.appendChild(el)}const list=document.getElementById('moduleList');list.replaceChildren();for(const m of d.module_inventory){const row=document.createElement('div');row.className='module-row';const n=document.createElement('span');n.textContent=m.name;const s=document.createElement('span');s.textContent=m.status_label;s.className=m.status;row.append(n,s);list.appendChild(row)}draw(d.history||[])}catch(err){const s=document.getElementById('status');s.textContent='ПОМИЛКА API';s.className='pill red'}}
function draw(h){const c=document.getElementById('chart'),x=c.getContext('2d'),w=c.width,H=c.height;x.clearRect(0,0,w,H);x.strokeStyle='#34465c';x.beginPath();x.moveTo(48,15);x.lineTo(48,H-30);x.lineTo(w-15,H-30);x.stroke();if(!h.length)return;const vals=h.map(v=>Number(v.evolution_pct)||0),min=Math.min(-1,...vals),max=Math.max(3,...vals),range=max-min||1;const xp=i=>48+i*(w-70)/Math.max(1,h.length-1),yp=v=>15+(max-v)*(H-48)/range;x.strokeStyle='#22ce88';x.lineWidth=3;x.beginPath();h.forEach((v,i)=>i?x.lineTo(xp(i),yp(v.evolution_pct)):x.moveTo(xp(i),yp(v.evolution_pct)));x.stroke();const ty=yp(3);x.strokeStyle='#d9ad42';x.setLineDash([6,5]);x.beginPath();x.moveTo(48,ty);x.lineTo(w-15,ty);x.stroke();x.setLineDash([]);x.fillStyle='#d9ad42';x.fillText('+3%',w-48,ty-6);x.fillStyle='#9aabc0';const step=Math.max(1,Math.ceil(h.length/8));h.forEach((v,i)=>{if(i%step===0||i===h.length-1){x.fillText(v.day,xp(i)-18,H-10);x.fillText('+'+v.created_files,xp(i)-8,H-36)}})}
refresh();setInterval(refresh,15000);
</script></html>"""

class Handler(BaseHTTPRequestHandler):
    def send_body(self, code, body, ctype):
        data = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        route = urlparse(self.path).path
        if route == "/":
            self.send_body(200, PAGE, "text/html; charset=utf-8")
        elif route == "/api/state":
            self.send_body(200, json.dumps(collect(), ensure_ascii=False), "application/json; charset=utf-8")
        elif route == "/health":
            self.send_body(200, '{"ok":true,"mode":"read-only","restart":"manual-only"}', "application/json")
        else:
            self.send_body(404, '{"error":"not found"}', "application/json")

    def log_message(self, fmt, *args):
        print("[%s] %s" % (self.log_date_time_string(), fmt % args))

if __name__ == "__main__":
    print("CYBRA Evolution Dashboard — local / read-only")
    print("ROOT:", ROOT)
    print("URL: http://127.0.0.1:%s/" % PORT)
    print("Restart policy: MANUAL_ONLY")
    ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
