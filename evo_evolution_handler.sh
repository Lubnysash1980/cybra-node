#!/data/data/com.termux/files/usr/bin/bash
set -u
cd "$HOME/CYBRA"

REASON=$(printf '%s' "${CYBRA_TASK_JSON:-{\}}" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("reason",""))' 2>/dev/null)
FROM=$(printf '%s' "${CYBRA_TASK_JSON:-{\}}" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("from_pct",0))' 2>/dev/null)
TO=$(printf '%s' "${CYBRA_TASK_JSON:-{\}}" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("to_pct",0))' 2>/dev/null)
TOPIC=$(printf '%s' "${CYBRA_TASK_JSON:-{\}}" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("topic","evo_" + str(int(__import__("time").time()))))' 2>/dev/null)

# 1. fix у фоні через окрему чергу (не блокувати)
FIX_NOTE="queued"
printf '{"topic":"%s","reason":"%s"}' "$TOPIC" "$REASON" | redis-cli -x rpush cybra:fix:queue >/dev/null 2>&1

# 2. rebuild → в чергу (worker зробить, не блокує парламент)
printf '{"topic":"%s","reason":"%s","from_pct":%s,"to_pct":%s}' \
  "$TOPIC" "$REASON" "$FROM" "$TO" | redis-cli -x rpush cybra:rebuild:queue >/dev/null

# 3. швидко повернути (не чекаючи rebuild)
printf '{"ok":true,"queued":"rebuild","topic":"%s","reason":"%s","from_pct":%s,"to_pct":%s,"fix":"%s"}\n' \
  "$TOPIC" "$REASON" "$FROM" "$TO" "$FIX_NOTE"
