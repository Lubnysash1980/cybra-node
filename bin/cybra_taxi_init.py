#!/usr/bin/env python3
import os, sys, subprocess
from pathlib import Path
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS = CYBRA / "modules"; CTRL = CYBRA / "controllers"
TAXI_MENU_DIR = MODS / "module_200_taxi_menu"
TAXI_MENU = TAXI_MENU_DIR / "bin/cybra_taxi_menu.sh"
CTRL.mkdir(exist_ok=True)
SPEC = {
 200:("book_ride","booking","create"),201:("cancel_ride","booking","cancel"),
 202:("ride_status","booking","status"),203:("ride_history","booking","list"),
 204:("estimate_price","booking","estimate"),205:("select_tariff","booking","tariff"),
 206:("schedule_ride","booking","schedule"),207:("repeat_ride","booking","repeat"),
 208:("favorite_route","booking","add"),209:("saved_addresses","booking","list"),
 210:("driver_register","driver","register"),211:("driver_status","driver","status"),
 212:("accept_ride","driver","accept"),213:("complete_ride","driver","complete"),
 214:("driver_earnings","driver","show"),215:("driver_documents","driver","upload"),
 216:("driver_rating","driver","show"),217:("dispatch_nearest","dispatch","find"),
 218:("dispatch_batch","dispatch","batch"),219:("surge_pricing","dispatch","calc"),
 220:("ride_payment","payment","charge"),221:("ride_receipt","payment","receipt"),
 222:("ride_refund","payment","refund"),223:("escrow_ride","payment","escrow"),
 224:("driver_payout","payment","payout"),225:("tip_driver","payment","tip"),
 226:("subscription","payment","show"),227:("wallet_topup","payment","topup"),
 228:("payment_history","payment","list"),229:("promo_code","payment","apply"),
 230:("ai_dispatcher","ai","dispatch"),231:("ai_chat_support","ai","chat"),
 232:("ai_route_optimize","ai","optimize"),233:("ai_demand_forecast","ai","forecast"),
 234:("ai_driver_scoring","ai","score"),235:("ai_dispute","ai","resolve"),
 236:("rider_analytics","analytics","show"),237:("driver_analytics","analytics","show"),
 238:("fleet_analytics","analytics","show"),239:("taxi_metrics","analytics","show"),
}
MAIN = r'''#!/data/data/com.termux/files/usr/bin/bash
set -u
CYBRA="${{CYBRA:-$HOME/CYBRA}}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/taxi_{n:03d}.log"; mkdir -p "$(dirname "$LOG")"
log() {{ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }}
ACTION="${{1:-{act}}}"; shift $(( $# > 0 ? 1 : 0 ))
log "START {name} action=$ACTION args=$#"
case "$ACTION" in
  create|register|add|book|schedule)
    [ $# -lt 1 ] && {{ echo "usage: $0 $ACTION <id> [val]"; exit 1; }}
    redis-cli hset "cybra:taxi:{cat}:data" "$1" "${{2:-$(date +%s)}}" >/dev/null
    echo "✅ {cat}: $1" ;;
  list|status|show|history)
    N=$(redis-cli hlen "cybra:taxi:{cat}:data" 2>/dev/null || echo 0)
    echo "════ taxi {cat}: {name} ════"
    echo "  items: $N"
    [ "$N" -gt 0 ] && redis-cli hgetall "cybra:taxi:{cat}:data" | paste - - | head -20 | sed 's/^/  /' ;;
  cancel|delete|remove)
    [ $# -lt 1 ] && {{ echo "usage: $0 $ACTION <id>"; exit 1; }}
    redis-cli hdel "cybra:taxi:{cat}:data" "$1" >/dev/null
    echo "✅ cancelled: $1" ;;
  estimate|calc|score|forecast|optimize|dispatch|chat|resolve)
    echo "🧠 {name} (AI) args: $*" ;;
  *) echo "════ taxi {name} ════"; echo "  hint: $0 create|list|cancel <id>" ;;
esac
exit $?
'''
CTRL_T = r'''#!/data/data/com.termux/files/usr/bin/bash
set -u
M="$1"; shift
[ -f "$M" ] || {{ echo "❌ missing"; exit 2; }}
bash -n "$M" 2>/dev/null || {{ echo "❌ syntax"; exit 3; }}
[ $# -gt 0 ] && A=("$@") || A=("list")
bash "$M" "${{A[@]}}" </dev/null 2>&1; exit $?
'''
count=0
for n in range(200,240):
    name,cat,act = SPEC[n]
    d = MODS / f"module_{n:03d}_{name}"; d.mkdir(parents=True, exist_ok=True)
    m = d/"main.sh"; m.write_text(MAIN.format(n=n,name=name,cat=cat,act=act)); os.chmod(m,0o755)
    c = CTRL / f"taxi_module_{n:03d}.ctrl.sh"; c.write_text(CTRL_T.format(n=n)); os.chmod(c,0o755)
    count+=1
(TAXI_MENU_DIR/"bin").mkdir(parents=True, exist_ok=True)
lines = ["#!/data/data/com.termux/files/usr/bin/bash",'CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null','while true; do','  clear 2>/dev/null','  echo "════ CYBRA TAXI (40 modules) ════"','  bash "$HOME/CYBRA/bin/cybra_notify.sh" bar 2>/dev/null','  echo ""']
for n in range(200,240): lines.append(f'  echo "  [{n}] {SPEC[n][0]}"')
lines += ['  echo "  [n] Notif [0] Exit"','  read -r -p "  Choice: " c','  case "$c" in']
for n in range(200,240): lines.append(f'    {n}) M=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_{n}_*" | head -1); bash "$CYBRA/controllers/taxi_module_{n}.ctrl.sh" "$M/main.sh" 2>&1; read -r _ ;;')
lines += ['    n|N) bash "$CYBRA/bin/cybra_notify.sh" list 20; read -r _ ;;','    0|q) exit 0 ;;','  esac','done']
TAXI_MENU.write_text("\n".join(lines)+"\n"); os.chmod(TAXI_MENU,0o755)
ln = CYBRA/"taxi"
if ln.exists() or ln.is_symlink(): ln.unlink()
ln.symlink_to(TAXI_MENU)
print(f"✅ {count} taxi modules + menu")
