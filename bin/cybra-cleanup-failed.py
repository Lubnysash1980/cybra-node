#!/usr/bin/env python3
"""Знаходить файли що не пройшли 100% state → карантин (не видалення)."""
import os, json, shutil, subprocess
from pathlib import Path
from datetime import datetime, timezone

CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MASTER = CYBRA / "state/snapshots/_master.json"
QUARANTINE = CYBRA / "state/quarantine"
LOG = CYBRA / "logs/cleanup_failed.log"
QUARANTINE.mkdir(parents=True, exist_ok=True)
LOG.parent.mkdir(parents=True, exist_ok=True)

def log(msg):
    t = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    line = f"[{t}] {msg}"
    print(line, flush=True)
    with open(LOG, "a") as f: f.write(line + "\n")

if not MASTER.exists():
    log("❌ _master.json не знайдено — спершу: bash bin/cybra_autobuild_all.sh --state-only")
    raise SystemExit(1)

master = json.loads(MASTER.read_text())
failed = [i for i in master.get("items", []) if not i.get("ok")]
log(f"═══ CLEANUP FAILED ({len(failed)} з {master.get('total',0)}) ═══")

if not failed:
    log("✅ Всі файли пройшли 100% state — нема що чистити")
    raise SystemExit(0)

stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
batch = QUARANTINE / f"batch_{stamp}"
batch.mkdir(parents=True, exist_ok=True)

moved = 0
skipped = 0
report = []

for item in failed:
    item_id = item.get("id", "?")
    kind = item.get("kind", "?")
    detail = item.get("detail", "?")
    target = item.get("target")

    if not target:
        skipped += 1
        report.append({"id": item_id, "kind": kind, "detail": detail, "action": "skip (no target)"})
        continue

    src = Path(target)
    if not src.exists():
        skipped += 1
        report.append({"id": item_id, "kind": kind, "detail": detail, "action": "skip (missing file)"})
        continue

    # зберігаємо структуру: batch/kind/module_XXX/
    dst_dir = batch / kind
    dst_dir.mkdir(parents=True, exist_ok=True)
    dst = dst_dir / src.name

    try:
        shutil.move(str(src), str(dst))
        moved += 1
        log(f"  🗑 [{kind}] {item_id} → quarantine/{batch.name}/{kind}/{src.name} ({detail})")
        report.append({
            "id": item_id, "kind": kind, "detail": detail,
            "action": "quarantined", "from": str(src), "to": str(dst)
        })
    except Exception as e:
        skipped += 1
        log(f"  ❌ {item_id}: {e}")
        report.append({"id": item_id, "kind": kind, "detail": detail, "action": f"error: {e}"})

# звіт
report_file = QUARANTINE / f"cleanup_{stamp}.json"
report_file.write_text(json.dumps({
    "ts": datetime.now(timezone.utc).isoformat(),
    "batch": batch.name,
    "total_failed": len(failed),
    "moved": moved,
    "skipped": skipped,
    "items": report,
}, indent=2, ensure_ascii=False))

log("")
log(f"═══ DONE ═══")
log(f"  failed у master: {len(failed)}")
log(f"  переміщено:      {moved}")
log(f"  пропущено:       {skipped}")
log(f"  batch:           {batch}")
log(f"  звіт:            {report_file}")
log("")
log("── Наступний крок (regen _master без карантинованих) ──")
log("  bash bin/cybra_autobuild_all.sh --state-only")
