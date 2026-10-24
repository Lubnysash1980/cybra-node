#!/data/data/com.termux/files/usr/bin/bash
echo "═══ MENU 160 — ФІНАЛЬНИЙ ЗВІТ ═══"
echo "menu:queue:    $(redis-cli llen cybra:menu:queue)"
echo "menu:results:  $(redis-cli llen cybra:menu:results)"
echo "menu:failed:   $(redis-cli llen cybra:menu:failed)"
echo
echo "── Розподіл по статусах ──"
for st in done deferred failed; do
  n=$(redis-cli lrange cybra:menu:results 0 -1 2>/dev/null | grep -c "\"status\":\"$st\"")
  echo "  $st: $n"
done
echo
echo "── Розподіл по діях ──"
redis-cli lrange cybra:menu:results 0 -1 2>/dev/null \
  | python3 -c "
import sys, json, collections
c = collections.Counter()
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        d = json.loads(line)
        c[(d.get('action','?'), d.get('status','?'))] += 1
    except: pass
for (a,s), n in sorted(c.items()):
    print(f'  {a:30s} {s:10s} {n}')
"
echo
echo "── Level ──"
echo "  $(cat ~/CYBRA/state/cybra.level 2>/dev/null || echo ?)/7"
echo "  RAM: $(free -m | awk '/Mem:/{printf "%d%%",$3/$2*100}')"
