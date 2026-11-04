#!/data/data/com.termux/files/usr/bin/bash
# measure.sh — deviation vs baseline. Exit 1 if ROLLBACK needed.
set -u
MOD="$(cd "$(dirname "$0")/.." && pwd)"
CYBRA="$(cd "$MOD/../.." && pwd)"
BASE="$MOD/state/baseline.json"
[ -f "$BASE" ] || { echo '{"error":"no baseline"}'; exit 2; }

god=$(pgrep -f 'PM2.*God Daemon' | wc -l)
online=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="online")]|length')
errored=$(pm2 jlist 2>/dev/null | jq '[.[]|select(.pm2_env.status=="errored")]|length')
bg=$(kill -0 "$(cat "$CYBRA/.cache/bg_dump.pid" 2>/dev/null)" 2>/dev/null && echo 1 || echo 0)
aw=$(kill -0 "$(cat "$CYBRA/.cache/autowatch.pid" 2>/dev/null)" 2>/dev/null && echo 1 || echo 0)

b_god=$(jq -r '.god' "$BASE");     b_on=$(jq -r '.online' "$BASE")
b_er=$(jq -r '.errored' "$BASE");  b_bg=$(jq -r '.bg_dump' "$BASE")
b_aw=$(jq -r '.autowatch' "$BASE")

total=$(awk -v b_god="$b_god" -v c_god="$god" -v b_on="$b_on" -v c_on="$online" \
             -v b_er="$b_er"   -v c_er="$errored" -v b_bg="$b_bg" -v c_bg="$bg" \
             -v b_aw="$b_aw"   -v c_aw="$aw" '
BEGIN{
  d_god = (b_god==0) ? 0 : (b_god==c_god ? 0 : 1);
  d_on  = (b_on==0)  ? 0 : ((c_on-b_on)/b_on); if (d_on<0) d_on=-d_on;
  d_er  = (c_er>b_er) ? 1 : 0;
  d_bg  = (b_bg==c_bg) ? 0 : 1;
  d_aw  = (b_aw==c_aw) ? 0 : 1;
  print (d_god*3 + d_on*2 + d_er*2 + d_bg*2 + d_aw*2) / 11
}')

verdict=$(awk -v t="$total" 'BEGIN{ if(t>0.3) print "ROLLBACK"; else if(t>0.1) print "WARN"; else print "OK" }')

jq -n --argjson god "$god" --argjson on "$online" --argjson er "$errored" \
      --argjson bg "$bg" --argjson aw "$aw" --argjson dev "$total" --arg v "$verdict" \
  '{now:{god:$god,online:$on,errored:$er,bg_dump:$bg,autowatch:$aw},
    deviation:$dev, verdict:$v}' | tee "$MOD/state/last-measure.json"

[ "$verdict" = "ROLLBACK" ] && exit 1 || exit 0
