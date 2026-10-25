#!/data/data/com.termux/files/usr/bin/bash
# CYBRA NOTIFY — перегляд/фільтр/очищення сповіщень
# Джерела: HIDL notifications, parliament queue, health events
set -uo pipefail
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || exit 2
HIDL_NOTIF="$CYBRA/state/hidl/notifications.jsonl"
HEALTH="$CYBRA/state/health.json"
READ_FILE="$CYBRA/state/notify_read.jsonl"   # які вже прочитані
SEEN="$CYBRA/state/notify_seen.json"
mkdir -p "$(dirname "$HIDL_NOTIF")" "$(dirname "$SEEN")"

cmd_list(){
  local n="${1:-20}"
  local level="${2:-all}"
  if [ ! -f "$HIDL_NOTIF" ]; then echo "no notifications"; return; fi
  python3 - "$HIDL_NOTIF" "$n" "$level" <<'PY'
import sys, json
path, n, level = sys.argv[1], int(sys.argv[2]), sys.argv[3]
rows = []
for line in open(path):
    try: r = json.loads(line)
    except: continue
    if level != "all" and r.get("level") != level: continue
    rows.append(r)
rows = rows[-n:][::-1]
if not rows: print("no notifications"); sys.exit()
ICON = {"success":"🟢","info":"🔵","warn":"🟡","error":"🔴"}
for r in rows:
    ic = ICON.get(r.get("level","info"),"⚪")
    ts = r.get("ts","?")[:19].replace("T"," ")
    n_ = r.get("module",0)
    st = r.get("status","?")
    d = r.get("delta_pct",0)
    dt = f" Δ{d:+.2f}%" if d else ""
    gr = " (git↩)" if r.get("git_restore") else ""
    print(f"{ic} {ts}  mod{n_:03d}  {st:12}{dt}{gr}")
PY
}

cmd_stats(){
  if [ ! -f "$HIDL_NOTIF" ]; then echo "no notifications"; return; fi
  python3 - "$HIDL_NOTIF" <<'PY'
import sys, json
from collections import Counter
path = sys.argv[1]
c = Counter(); by_status = Counter()
total = 0
for line in open(path):
    try: r = json.loads(line)
    except: continue
    total += 1
    c[r.get("level","info")] += 1
    by_status[r.get("status","?")] += 1
print(f"═══ NOTIFY STATS ═══")
print(f"  total:    {total}")
for k in ("success","info","warn","error"):
    print(f"  {k:8} {c.get(k,0)}")
print(f"  ─── by status ───")
for k,v in by_status.most_common(10):
    print(f"  {k:15} {v}")
PY
}

cmd_unread(){
  # скільки warn+error з моменту останнього перегляду
  if [ ! -f "$HIDL_NOTIF" ]; then echo "0"; return; fi
  python3 - "$HIDL_NOTIF" "$SEEN" <<'PY'
import sys, json, os
path, seen_f = sys.argv[1], sys.argv[2]
last = 0
if os.path.exists(seen_f):
    try: last = json.load(open(seen_f)).get("last_idx",0)
    except: pass
lines = open(path).read().splitlines()
unread = 0
for i, ln in enumerate(lines):
    if i < last: continue
    try: r = json.loads(ln)
    except: continue
    if r.get("level") in ("warn","error"): unread += 1
print(unread)
PY
}

cmd_mark_read(){
  python3 - "$HIDL_NOTIF" "$SEEN" <<'PY'
import sys, json, os
path, seen_f = sys.argv[1], sys.argv[2]
total = 0
if os.path.exists(path):
    total = len([l for l in open(path) if l.strip()])
json.dump({"last_idx": total, "ts": __import__("datetime").datetime.utcnow().isoformat()+"Z"},
          open(seen_f,"w"))
print(f"✅ marked read: {total}")
PY
}

cmd_clear(){
  : > "$HIDL_NOTIF"
  : > "$SEEN" 2>/dev/null || true
  echo "✅ notifications cleared"
}

cmd_recent(){  # для топ-бару (компактно)
  local unread; unread=$(cmd_unread)
  local last
  last=$(python3 - "$HIDL_NOTIF" <<'PY' 2>/dev/null
import sys,json
try:
    lines=open(sys.argv[1]).read().splitlines()
    r=json.loads(lines[-1]) if lines else {}
    print(f"{r.get('level','?')}:mod{r.get('module',0):03d}:{r.get('status','?')}")
except: print("none")
PY
)
  echo "unread=$unread last=$last"
}

# ─── health summary (для бару) ───
cmd_bar(){
  local unread last health_ok ram
  unread=$(cmd_unread)
  if [ -f "$HIDL_NOTIF" ]; then
    last=$(tail -1 "$HIDL_NOTIF" 2>/dev/null | python3 -c "import sys,json;r=json.load(sys.stdin);print(f\"mod{r.get('module',0):03d} {r.get('status','?')}\")" 2>/dev/null || echo "—")
  else
    last="—"
  fi
  if [ -f "$HEALTH" ]; then
    health_ok=$(python3 -c "import json;print(json.load(open('$HEALTH')).get('status','?'))" 2>/dev/null || echo "?")
    ram=$(python3 -c "import json;print(json.load(open('$HEALTH')).get('ram_pct',0))" 2>/dev/null || echo "0")
  else
    health_ok="?"; ram="0"
  fi
  local icon="🟢"
  [ "$health_ok" = "degraded" ] && icon="🟡"
  [ "$health_ok" = "critical" ] && icon="🔴"
  local bell=""
  [ "$unread" -gt 0 ] && bell=" 🔔$unread"
  printf "%s health:%s RAM:%s%% 🔔%d  last: %s" "$icon" "$health_ok" "$ram" "$unread" "$last"
}

case "${1:-list}" in
  list)    shift; cmd_list "${1:-20}" "${2:-all}" ;;
  warn)    cmd_list 20 warn ;;
  error)   cmd_list 20 error ;;
  stats)   cmd_stats ;;
  unread)  cmd_unread ;;
  read)    cmd_mark_read ;;
  clear)   cmd_clear ;;
  bar)     cmd_bar ;;
  recent)  cmd_recent ;;
  *)
    cat <<USAGE
usage: $0 <command> [args]
  list [N] [level]    останні N (default 20), фільтр level=all|success|info|warn|error
  warn                тільки warn
  error               тільки error
  stats               статистика по рівнях
  unread              кількість непрочитаних (warn+error)
  read                помітити все прочитаним
  clear               очистити
  bar                 один рядок для меню (health + unread + last)
USAGE
    ;;
esac
