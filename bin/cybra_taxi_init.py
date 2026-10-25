#!/usr/bin/env python3
"""TAXI SERVICE — 40 модулів (200-239) + власне меню.
   Категорії: booking, dispatch, driver, rider, payment, support, ai, analytics.
   Не чіпає модулі 1-160.
"""
import os, sys, json, subprocess, shutil, time
from pathlib import Path
CYBRA = Path(os.environ["HOME"]) / "CYBRA"
MODS  = CYBRA / "modules"
CTRL  = CYBRA / "controllers"
TAXI_MENU_DIR = MODS / "module_200_taxi_menu"
TAXI_MENU = TAXI_MENU_DIR / "bin/cybra_taxi_menu.sh"
SPEC_FILE = CYBRA / "state/taxi_spec.json"
BACKUP = CYBRA / "state/module_backups"
BACKUP.mkdir(parents=True, exist_ok=True)

# ─── SPEC: 40 модулів таксі ───
# (n, name, category, default_action)
TAXI_SPEC = {
    # 200-209: BOOKING (rider side)
    200: ("book_ride",       "booking", "create"),
    201: ("cancel_ride",     "booking", "cancel"),
    202: ("ride_status",     "booking", "status"),
    203: ("ride_history",    "booking", "list"),
    204: ("estimate_price",  "booking", "estimate"),
    205: ("select_tariff",   "booking", "tariff"),
    206: ("schedule_ride",   "booking", "schedule"),
    207: ("repeat_ride",     "booking", "repeat"),
    208: ("favorite_route",  "booking", "add"),
    209: ("saved_addresses", "booking", "list"),

    # 210-219: DISPATCH + DRIVER
    210: ("driver_register", "driver",  "register"),
    211: ("driver_status",   "driver",  "status"),
    212: ("accept_ride",     "driver",  "accept"),
    213: ("complete_ride",   "driver",  "complete"),
    214: ("driver_earnings", "driver",  "show"),
    215: ("driver_documents","driver",  "upload"),
    216: ("driver_rating",   "driver",  "show"),
    217: ("dispatch_nearest","dispatch","find"),
    218: ("dispatch_batch",  "dispatch", "batch"),
    219: ("surge_pricing",   "dispatch","calc"),

    # 220-229: PAYMENT + ESCROW
    220: ("ride_payment",    "payment", "charge"),
    221: ("ride_receipt",    "payment", "receipt"),
    222: ("ride_refund",     "payment", "refund"),
    223: ("escrow_ride",     "payment", "escrow"),
    224: ("driver_payout",   "payment", "payout"),
    225: ("tip_driver",      "payment", "tip"),
    226: ("subscription",    "payment", "show"),
    227: ("wallet_topup",    "payment", "topup"),
    228: ("payment_history", "payment", "list"),
    229: ("promo_code",      "payment", "apply"),

    # 230-239: AI SUPPORT + ANALYTICS
    230: ("ai_dispatcher",   "ai",      "dispatch"),
    231: ("ai_chat_support", "ai",      "chat"),
    232: ("ai_route_optimize","ai",     "optimize"),
    233: ("ai_demand_forecast","ai",    "forecast"),
    234: ("ai_driver_scoring","ai",     "score"),
    235: ("ai_dispute",      "ai",      "resolve"),
    236: ("rider_analytics", "analytics","show"),
    237: ("driver_analytics","analytics","show"),
    238: ("fleet_analytics", "analytics","show"),
    239: ("taxi_metrics",    "analytics","show"),
}

MAIN_TPL = r'''#!/data/data/com.termux/files/usr/bin/bash
# taxi module_{n:03d}: {name} ({cat})
set -u
CYBRA="${{CYBRA:-$HOME/CYBRA}}"; cd "$CYBRA" 2>/dev/null || exit 1
LOG="$CYBRA/logs/taxi_{n:03d}.log"; mkdir -p "$(dirname "$LOG")"
log() {{ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }}
err() {{ log "ERR: $*"; echo "❌ $*" >&2; return 1; }}
trap 'err "line $LINENO"' ERR
ACTION="${{1:-{action}}}"; shift $(( $# > 0 ? 1 : 0 ))
log "START {name} action=$ACTION"

case "$ACTION" in
  add|create|register|schedule|book)
    [ $# -lt 1 ] && {{ echo "usage: $0 $ACTION <id> [value]"; exit 1; }}
    ID="$1"; VAL="${{2:-$(date +%s)}}"
    redis-cli hset "cybra:taxi:{cat}:data" "$ID" "$VAL" >/dev/null
    echo "✅ {cat}: $ID registered" ;;
  list|history|show|status)
    N=$(redis-cli hlen "cybra:taxi:{cat}:data" 2>/dev/null || echo 0)
    echo "════ taxi {cat}: {name} (module_{n:03d}) ════"
    echo "  items: $N"
    [ "$N" -gt 0 ] && redis-cli hgetall "cybra:taxi:{cat}:data" | paste - - | head -20 | sed 's/^/  /' ;;
  cancel|delete|remove)
    [ $# -lt 1 ] && {{ echo "usage: $0 $ACTION <id>"; exit 1; }}
    redis-cli hdel "cybra:taxi:{cat}:data" "$1" >/dev/null
    echo "✅ cancelled: $1" ;;
  estimate|calc|score|forecast|optimize|dispatch)
    echo "🧠 {name}: AI-режим"
    echo "  args: $*"
    echo "  hint: реагує через AI (cybra_local_ai.sh), fallback redis" ;;
  *)
    echo "════ taxi {name} (module_{n:03d}) ════"
    echo "  action: $ACTION  category: {cat}"
    echo "  hint: $0 create|list|cancel <id>" ;;
esac
rc=$?; log "DONE rc=$rc"; exit $rc
'''

CTRL_TPL = r'''#!/data/data/com.termux/files/usr/bin/bash
set -u
MODULE="$1"; shift
LOG="$HOME/CYBRA/logs/taxi_ctrl_{n:03d}.log"; mkdir -p "$(dirname "$LOG")"
log() {{ echo "[$(date -u +%FT%TZ)] $*" >> "$LOG"; }}
log "ctrl_{n:03d} args=$#"
[ -f "$MODULE" ] || {{ echo "❌ missing"; exit 2; }}
bash -n "$MODULE" 2>/dev/null || {{ echo "❌ syntax"; exit 3; }}
[ $# -gt 0 ] && ARGS=("$@") || ARGS=("list")
out=$(bash "$MODULE" "${{ARGS[@]}}" </dev/null 2>&1); rc=$?
log "rc=$rc"
printf '%s\n' "$out"
exit $rc
'''

TAXI_MENU_TPL = r'''#!/data/data/com.termux/files/usr/bin/bash
# CYBRA TAXI MENU
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || exit 1
NOTIFY="bash $CYBRA/bin/cybra_notify.sh bar 2>/dev/null"

show_header() {{
  clear 2>/dev/null
  echo "════════════════════════════════════════════════════════════"
  echo "  🚕 CYBRA TAXI — GLOBAL SERVICE  │  40 modules (200-239)"
  echo "  $(eval $NOTIFY)"
  echo "  $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
  echo "────────────────────────────────────────────────────────────"
}}

main_menu() {{
  show_header
  echo ""
  echo "  ─── BOOKING (rider) ───"
  echo "  [200] Book ride           [201] Cancel          [202] Ride status"
  echo "  [203] History             [204] Estimate        [205] Select tariff"
  echo "  [206] Schedule            [207] Repeat          [208] Favorite route"
  echo "  [209] Saved addresses"
  echo ""
  echo "  ─── DRIVER ───"
  echo "  [210] Register            [211] Status          [212] Accept ride"
  echo "  [213] Complete            [214] Earnings        [215] Documents"
  echo "  [216] Rating"
  echo ""
  echo "  ─── DISPATCH ───"
  echo "  [217] Nearest             [218] Batch           [219] Surge"
  echo ""
  echo "  ─── PAYMENT ───"
  echo "  [220] Charge              [221] Receipt         [222] Refund"
  echo "  [223] Escrow              [224] Payout          [225] Tip"
  echo "  [226] Subscription        [227] Topup           [228] History"
  echo "  [229] Promo"
  echo ""
  echo "  ─── AI SUPPORT ───"
  echo "  [230] AI dispatcher       [231] AI chat         [232] Route optimize"
  echo "  [233] Demand forecast     [234] Driver scoring  [235] AI dispute"
  echo ""
  echo "  ─── ANALYTICS ───"
  echo "  [236] Rider               [237] Driver          [238] Fleet"
  echo "  [239] Metrics"
  echo ""
  echo "  [n] Notifications         [h] Health           [0] Exit"
  echo ""
  read -r -p "  Choice: " c
  case "$c" in
    200|201|202|203|204|205|206|207|208|209|210|211|212|213|214|215|216|217|218|219|220|221|222|223|224|225|226|227|228|229|230|231|232|233|234|235|236|237|238|239)
      MOD=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_${{c}}_*" 2>/dev/null | head -1)
      CTRL="$CYBRA/controllers/taxi_module_${{c}}.ctrl.sh"
      [ -f "$CTRL" ] && [ -n "$MOD" ] && bash "$CTRL" "$MOD/main.sh"
      read -r -p "Enter..." _ ;;
    n|N) bash "$CYBRA/bin/cybra_notify.sh" list 20; read -r -p "Enter..." _ ;;
    h|H) bash "$CYBRA/bin/cybra_health.sh" 2>&1 | tail -10; read -r -p "Enter..." _ ;;
    0|q|Q) exit 0 ;;
    *) ;;
  esac
}}

while true; do main_menu; done
'''

def find_or_create(n, name):
    for pat in [f"module_{n:03d}_*", f"module_{n}_*"]:
        for d in sorted(MODS.glob(pat)):
            if d.is_dir(): return d
    d = MODS / f"module_{n:03d}_{name}"
    d.mkdir(parents=True, exist_ok=True)
    return d

def main():
    print("═══ TAXI BOOTSTRAP (modules 200-239) ═══")
    ts = time.strftime("%Y%m%d_%H%M%S")
    bkp = BACKUP / f"taxi_{ts}.tar.gz"

    main_ok = ctrl_ok = 0
    ctrl_files = []

    for n in range(200, 240):
        name, cat, action = TAXI_SPEC[n]
        d = find_or_create(n, name)
        m = d / "main.sh"
        m.write_text(MAIN_TPL.format(n=n, name=name, cat=cat, action=action))
        os.chmod(m, 0o755)
        if subprocess.run(["bash", "-n", str(m)], capture_output=True).returncode == 0:
            main_ok += 1

        c = CTRL / f"taxi_module_{n:03d}.ctrl.sh"
        c.write_text(CTRL_TPL.format(n=n))
        os.chmod(c, 0o755)
        if subprocess.run(["bash", "-n", str(c)], capture_output=True).returncode == 0:
            ctrl_ok += 1
            ctrl_files.append((n, str(m), str(c)))

    print(f"✅ main: {main_ok}/40")
    print(f"✅ ctrl: {ctrl_ok}/40")

    # taxi menu
    (TAXI_MENU_DIR / "bin").mkdir(parents=True, exist_ok=True)
    TAXI_MENU.write_text(TAXI_MENU_TPL)
    os.chmod(TAXI_MENU, 0o755)
    if subprocess.run(["bash","-n",str(TAXI_MENU)], capture_output=True).returncode == 0:
        print(f"✅ taxi menu: {TAXI_MENU}")
    else:
        print("❌ taxi menu syntax broken")
        return

    # symlink для швидкого запуску
    ln = CYBRA / "taxi"
    if ln.exists() or ln.is_symlink(): ln.unlink()
    ln.symlink_to(TAXI_MENU)
    os.chmod(TAXI_MENU, 0o755)

    # spec
    spec = {n: {"name": v[0], "cat": v[1], "action": v[2]}
            for n, v in TAXI_SPEC.items()}
    SPEC_FILE.write_text(json.dumps({
        "generated": ts, "taxi_version": "1.0",
        "modules": spec,
        "categories": {
            "booking":  "Rider — book/cancel/history",
            "driver":   "Driver — register/status/accept/complete/earnings",
            "dispatch": "Auto-dispatch + surge",
            "payment":  "Charge/escrow/payout/refund",
            "ai":       "AI-підтримка: chat, dispatch, forecast, dispute",
            "analytics": "Rider/driver/fleet metrics",
        },
        "next_steps": [
            "Заповнити семантику: driver_register → створити запис у cybra:taxi:driver",
            "AI chat: підключити cybra_local_ai.sh замість echo",
            "Payment: зв'язати з cybra:parliament:queue → escrow contract",
            "Dispatch: redis GEOSEARCH для найближчих водіїв",
        ],
    }, indent=2, ensure_ascii=False))

    # test 5
    print("\n── TEST 5 ──")
    for n in [200, 210, 220, 230, 239]:
        d = next(MODS.glob(f"module_{n:03d}_*"), None)
        if not d: continue
        r = subprocess.run(["bash", str(d/"main.sh"), "list"], capture_output=True, text=True, timeout=10, input="")
        ok = "✅" if r.returncode == 0 and len(r.stdout.splitlines()) >= 2 else "❌"
        print(f"  [{n}] {ok} {r.stdout.splitlines()[0] if r.stdout else 'empty'}")

    print(f"\n  📁 modules 200-239: {len(list(MODS.glob('module_2[0-3][0-9]_*')))}")
    print(f"  📁 ctrl: {len(list(CTRL.glob('taxi_module_*.ctrl.sh')))}")
    print(f"  📋 spec: {SPEC_FILE}")
    print(f"  🚕 launch: ~/CYBRA/taxi")

if __name__ == "__main__":
    main()
