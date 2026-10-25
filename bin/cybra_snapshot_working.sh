#!/data/data/com.termux/files/usr/bin/bash
# SNAPSHOT робочості: AI + парламент + цілі + скрипти
# Не чіпає нічого — тільки читає, класифікує, пакує, пише маніфест
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1
TS=$(date +%Y%m%d_%H%M%S)
OUT_DIR="$CYBRA/snapshots/working_$TS"
ARCHIVE="$CYBRA/snapshots/cybra_working_$TS.tar.gz"
MANIFEST="$OUT_DIR/manifest.json"
mkdir -p "$OUT_DIR"

echo "═══ SNAPSHOT WORKING [$TS] ═══"
echo "  output: $OUT_DIR"
echo ""

# ─── 1. Аудит робочості (Python) ───
python3 - "$CYBRA" "$OUT_DIR" <<'PY'
import sys, os, re, json, subprocess, hashlib
from pathlib import Path
from datetime import datetime, timezone

CYBRA, OUT = Path(sys.argv[1]), Path(sys.argv[2])
STUB_RE = re.compile(r'AI-INTEGRATED|потребує наповнення|smart-stub v1|МОДУЛЬ.*створено заново|# BROKEN', re.I)
REAL_HINTS = [
    r'redis-cli', r'git --no-pager', r'pm2 jlist', r'python3 ',
    r'cybra_[a-z_]+', r'sqlite', r'curl', r'fidic', r'parliament',
    r'hidl', r'baseline', r'dispatch',
]

def classify(path):
    """REAL / STUB / EMPTY / MISSING / BROKEN"""
    p = Path(path)
    if not p.exists(): return "MISSING", 0
    t = p.read_text(errors="ignore")
    if not t.strip(): return "EMPTY", 0
    if STUB_RE.search(t): return "STUB", len(t)
    real_hits = sum(1 for r in REAL_HINTS if re.search(r, t))
    if len(t) < 200: return "STUB", len(t)
    if subprocess.run(["bash","-n",str(p)], capture_output=True).returncode != 0 and p.suffix == ".sh":
        return "BROKEN", len(t)
    if real_hits >= 2: return "REAL", len(t)
    if real_hits == 1: return "PARTIAL", len(t)
    return "STUB", len(t)

def scan_dir(root, patterns, depth=3):
    root = Path(root)
    out = []
    if not root.exists(): return out
    for pat in patterns:
        for p in root.rglob(pat):
            if p.is_file() and p.stat().st_size > 30:
                if any(x in str(p) for x in ("/node_modules/", "/.git/", "/state/evo_", "/backups/")):
                    continue
                cls, size = classify(p)
                out.append({
                    "path": str(p.relative_to(CYBRA)),
                    "class": cls,
                    "bytes": size,
                    "mtime": datetime.fromtimestamp(p.stat().st_mtime).isoformat(),
                })
    return sorted(out, key=lambda x: (-x["bytes"], x["path"]))

# ─── A. AI слои ───
ai_files = []
for pat in ("*ai*", "*neural*", "*brain*", "*llm*", "*gpt*"):
    ai_files.extend(scan_dir(CYBRA, [f"{pat}.py", f"{pat}.sh", f"{pat}*.py", f"{pat}*.sh"]))
# видалити дублі
seen = set(); ai_uniq = []
for f in ai_files:
    if f["path"] in seen: continue
    seen.add(f["path"]); ai_uniq.append(f)

# ─── B. Парламент ───
parl_files = []
for pat in ("parliament*", "*parliament*", "priority_manager*", "*hidl*", "*menu_worker*"):
    parl_files.extend(scan_dir(CYBRA, [f"{pat}.py", f"{pat}.sh"]))
seen = set(); parl_uniq = []
for f in parl_files:
    if f["path"] in seen: continue
    seen.add(f["path"]); parl_uniq.append(f)

# ─── C. Цілі ───
goals = []
for p in [CYBRA/"cybra_goal.json", CYBRA/"state/goal.json", CYBRA/"GOAL.json"]:
    if p.exists():
        try:
            goals.append({"path": str(p.relative_to(CYBRA)), "content": json.loads(p.read_text())})
        except Exception as e:
            goals.append({"path": str(p.relative_to(CYBRA)), "error": str(e)})
# також state/*.json де є "goal" або "baseline" або "level"
for p in (CYBRA/"state").glob("*.json"):
    try:
        d = json.loads(p.read_text())
        keys = set(d.keys()) if isinstance(d, dict) else set()
        if keys & {"goal", "baseline", "avg", "level", "target", "priority"}:
            goals.append({"path": str(p.relative_to(CYBRA)), "keys": list(keys)[:10]})
    except: pass

# ─── D. Скрипти, які реально "make it work" ───
make_it_work = []
for p in (CYBRA/"bin").glob("cybra_*.sh"):
    if p.is_file():
        cls, size = classify(p)
        if cls == "REAL": make_it_work.append({"path": str(p.relative_to(CYBRA)), "bytes": size})
for p in (CYBRA/"bin").glob("cybra_*.py"):
    if p.is_file():
        cls, size = classify(p)
        if cls == "REAL": make_it_work.append({"path": str(p.relative_to(CYBRA)), "bytes": size})

# ─── E. Модулі (агрегат) ───
mods_root = CYBRA / "modules"
mods_stats = {"total_dirs": 0, "with_main": 0, "REAL": 0, "STUB": 0, "MISSING": 0}
for d in mods_root.glob("module_*"):
    if not d.is_dir(): continue
    mods_stats["total_dirs"] += 1
    m = d / "main.sh"
    if m.exists():
        mods_stats["with_main"] += 1
        cls, _ = classify(m)
        if cls in mods_stats: mods_stats[cls] += 1
    else:
        mods_stats["MISSING"] += 1

# ─── F. Runtime station ───
runtime = {"redis": "?"}
try:
    r = subprocess.run(["redis-cli","ping"], capture_output=True, text=True, timeout=3)
    runtime["redis"] = r.stdout.strip() if r.returncode == 0 else "DOWN"
except: pass

try:
    r = subprocess.run(["pm2","jlist"], capture_output=True, text=True, timeout=5)
    if r.returncode == 0:
        procs = json.loads(r.stdout)
        runtime["pm2_online"] = [p["name"] for p in procs if p["pm2_env"]["status"] == "online"]
        runtime["pm2_stopped"] = [p["name"] for p in procs if p["pm2_env"]["status"] != "online"]
except: pass

# ─── G. Evo baseline ───
evo = {}
bp = CYBRA / "state/evo_baseline.json"
if bp.exists():
    try:
        d = json.loads(bp.read_text())
        evo = {"avg": d.get("avg"), "locked_at": d.get("locked_at"),
               "modules_scored": len(d.get("modules", {}))}
    except: pass

# ─── H. Redis стан (що є в памʼяті) ───
redis_keys = {}
try:
    for pattern in ("cybra:menu:*", "cybra:hidl:*", "cybra:taxi:*", "cybra:parliament:*"):
        r = subprocess.run(["redis-cli","--scan","--pattern",pattern],
                           capture_output=True, text=True, timeout=5)
        k = [x for x in r.stdout.strip().split("\n") if x]
        if k: redis_keys[pattern] = {"count": len(k), "sample": k[:5]}
except: pass

# ─── J. Збираємо манифест ───
manifest = {
    "ts": datetime.now(timezone.utc).isoformat(),
    "snapshot_version": "1.0",
    "device": subprocess.run(["uname","-n"], capture_output=True, text=True).stdout.strip(),
    "ai": {
        "total_files": len(ai_uniq),
        "real": [f for f in ai_uniq if f["class"] == "REAL"][:20],
        "stub": [f for f in ai_uniq if f["class"] == "STUB"][:10],
        "missing": [f for f in ai_uniq if f["class"] == "MISSING"],
    },
    "parliament": {
        "total_files": len(parl_uniq),
        "real": [f for f in parl_uniq if f["class"] == "REAL"],
        "stub": [f for f in parl_uniq if f["class"] == "STUB"],
    },
    "goals": goals,
    "make_it_work_scripts": make_it_work,
    "modules": mods_stats,
    "runtime": runtime,
    "evo_baseline": evo,
    "redis_keys": redis_keys,
}

(OUT/"manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False))

# ─── Саммари ───
print(f"  AI files:          {len(ai_uniq)}  (REAL: {len(manifest['ai']['real'])}, STUB: {len(manifest['ai']['stub'])})")
print(f"  Parliament files:  {len(parl_uniq)}  (REAL: {len(manifest['parliament']['real'])}, STUB: {len(manifest['parliament']['stub'])})")
print(f"  Goals:             {len(goals)}")
print(f"  Make-it-work:      {len(make_it_work)}")
print(f"  Modules:           {mods_stats['total_dirs']} dirs / {mods_stats['with_main']} main.sh / REAL {mods_stats['REAL']} / STUB {mods_stats['STUB']}")
print(f"  Redis:             {runtime.get('redis','?')}")
print(f"  PM2 online:        {len(runtime.get('pm2_online',[]))}")
print(f"  Evo avg:           {evo.get('avg','?')}")
PY

# ─── 2. Копіюємо критичні файли ───
echo ""
echo "── копіювання файлів ──"
mkdir -p "$OUT_DIR/files"

# тільки реальні скрипти
if [ -f "$OUT_DIR/manifest.json" ]; then
  python3 - "$OUT_DIR" "$CYBRA" <<'PY'
import sys, json, shutil
from pathlib import Path
OUT, CYBRA = Path(sys.argv[1]), Path(sys.argv[2])
m = json.loads((OUT/"manifest.json").read_text())

copied = 0
for section in ("ai","parliament","make_it_work_scripts"):
    items = m.get(section, {})
    if isinstance(items, dict):
        items = items.get("real", []) + items.get("stub", [])
    for item in items:
        rel = item.get("path")
        if not rel: continue
        src = CYBRA / rel
        if not src.exists() or not src.is_file(): continue
        if src.stat().st_size > 200_000: continue  # skip big
        dst = OUT/"files"/rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        try:
            shutil.copy2(src, dst); copied += 1
        except: pass

# goals + baseline
for rel in ["cybra_goal.json", "state/evo_baseline.json", "state/modules_spec.json",
            "state/hidl/hidl_schema.json"]:
    src = CYBRA / rel
    if src.exists():
        dst = OUT/"files"/rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst); copied += 1

print(f"  copied: {copied} files")
PY
fi

# ─── 3. Runtime dump (redis + pm2 state) ───
echo ""
echo "── runtime dump ──"
{
  echo "=== PM2 STATE ==="
  pm2 jlist 2>/dev/null
  echo ""
  echo "=== REDIS INFO ==="
  redis-cli info 2>/dev/null | head -40
  echo ""
  echo "=== REDIS KEYS (cybra:*) ==="
  redis-cli --scan --pattern 'cybra:*' 2>/dev/null | head -200
} > "$OUT_DIR/runtime_dump.txt"
echo "  ✅ $(wc -l < "$OUT_DIR/runtime_dump.txt") lines"

# ─── 4. Пакуємо ───
echo ""
echo "── пакування ──"
tar -czf "$ARCHIVE" -C "$CYBRA/snapshots" "working_$TS"
SIZE=$(du -h "$ARCHIVE" | awk '{print $1}')
echo "  ✅ $ARCHIVE ($SIZE)"

# ─── 5. Звіт ───
echo ""
echo "═══ SNAPSHOT READY ═══"
echo "  archive:  $ARCHIVE"
echo "  size:     $SIZE"
echo "  manifest: $OUT_DIR/manifest.json"
echo "  files:    $OUT_DIR/files/"
echo "  runtime:  $OUT_DIR/runtime_dump.txt"
echo ""
echo "  для іншого пристрою:"
echo "    scp $ARCHIVE <device>:~/"
echo "    або: git tag + push"
echo ""
echo "  перегляд маніфесту:"
echo "    jq '.ai.real[]' $OUT_DIR/manifest.json"
echo "    jq '.parliament.real[]' $OUT_DIR/manifest.json"
echo "    jq '.modules' $OUT_DIR/manifest.json"
