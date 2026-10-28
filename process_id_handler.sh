#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"

ACT=$(printf '%s' "${CYBRA_TASK_JSON:-{\}}" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("action","list"))' 2>/dev/null)
NAME=$(printf '%s' "${CYBRA_TASK_JSON:-{\}}" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("name",""))' 2>/dev/null)

case "$ACT" in
  list|pids)
    pm2 jlist 2>/dev/null | python3 -c '
import sys, json
d = json.load(sys.stdin)
print("pm2_id   os_pid   status       name")
print("-" * 50)
for p in sorted(d, key=lambda x: x["pm_id"]):
    print("%6d %8d %10s %s" % (
        p["pm_id"], p.get("pid", 0),
        p["pm2_env"]["status"], p["name"]
    ))
'
    ;;

  check)
    [ -z "$NAME" ] && { echo '{"ok":false,"error":"name required"}'; exit 1; }
    pm2 jlist 2>/dev/null | python3 -c "
import sys, json, os
d = json.load(sys.stdin)
for p in d:
    if p['name'] == '$NAME':
        pid = p.get('pid', 0)
        alive = False
        if pid:
            try: os.kill(pid, 0); alive = True
            except: pass
        print(json.dumps({
            'ok': True, 'name': '$NAME', 'pm2_id': p['pm_id'],
            'os_pid': pid, 'status': p['pm2_env']['status'],
            'os_alive': alive,
            'restarts': p['pm2_env'].get('restart_time', 0),
        }))
        sys.exit(0)
print('{\"ok\":false,\"error\":\"not found: $NAME\"}')
sys.exit(1)
"
    ;;

  kill)
    [ -z "$NAME" ] && { echo '{"ok":false,"error":"name required"}'; exit 1; }
    pm2 delete "$NAME" 2>/dev/null && pm2 save >/dev/null 2>&1
    echo "{\"ok\":true,\"killed\":\"$NAME\"}"
    ;;

  restart)
    [ -z "$NAME" ] && { echo '{"ok":false,"error":"name required"}'; exit 1; }
    pm2 restart "$NAME" >/dev/null 2>&1
    echo "{\"ok\":true,\"restarted\":\"$NAME\"}"
    ;;

  *)
    echo "{\"ok\":false,\"error\":\"unknown action: $ACT\"}"
    exit 1
    ;;
esac
