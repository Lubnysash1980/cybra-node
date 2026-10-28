#!/usr/bin/env python3
"""Кидає задачу в кіберпарламент і чекає результату. Usage: ai-writer.py <a|b>"""
import os, sys, json, time, uuid, pathlib, redis

if len(sys.argv) < 2 or sys.argv[1] not in ("a", "b"):
    print("usage: ai-writer.py <a|b>"); sys.exit(1)
X = sys.argv[1]

root = pathlib.Path(__file__).resolve().parent.parent
prompt_path = root / "prompts" / f"prog_{X}.md"
prog_file   = root / "programs" / f"prog_{X}" / "main.py"

if not prompt_path.exists():
    print(f"[writer-{X}] missing {prompt_path}"); sys.exit(1)

spec = prompt_path.read_text(encoding="utf-8")
prev = prog_file.read_text(encoding="utf-8") if prog_file.exists() else "(порожньо)"

user_msg = (
    f"ТЗ:\n{spec}\n\n"
    f"Поточний код (може бути порожній):\n```\n{prev}\n```\n\n"
    "Поверни ПОВНИЙ оновлений код файлу. Без markdown, без ```."
)

r = redis.Redis(host="127.0.0.1", port=6379, decode_responses=True)
try:
    r.ping()
except Exception as e:
    print(f"[writer-{X}] redis unavailable: {e}"); sys.exit(2)

job_id = f"prog_{X}_{uuid.uuid4().hex[:8]}"
task = {
    "topic": job_id,
    "type": "program_writer_task",
    "prog": X,
    "prompt": user_msg,
}
r.rpush("cybra:parliament:queue", json.dumps(task, ensure_ascii=False))
print(f"[writer-{X}] submitted {job_id}")

deadline = time.time() + 240
found = None
while time.time() < deadline:
    time.sleep(2)
    # Q_RESULTS — LPUSH, тому новіші спереду. Шукаємо у перших 200.
    items = r.lrange("cybra:parliament:results", 0, 199)
    for raw in items:
        try:
            obj = json.loads(raw)
        except Exception:
            continue
        if obj.get("topic") == job_id:
            found = obj; break
    if found: break

if not found:
    print(f"[writer-{X}] timeout waiting for {job_id}"); sys.exit(3)

status = found.get("status")
print(f"[writer-{X}] status={status} script={found.get('script')}")
if status != "executed":
    print(f"[writer-{X}] execution failed: {json.dumps(found, ensure_ascii=False)[:400]}")
    sys.exit(4)

if not prog_file.exists():
    print(f"[writer-{X}] handler didn't write {prog_file}"); sys.exit(5)

size = prog_file.stat().st_size
print(f"[writer-{X}] wrote {prog_file} ({size} bytes)")
