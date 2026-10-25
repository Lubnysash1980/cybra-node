#!/usr/bin/env python3
"""Taxi Premium: 20 нових модулів 240-259 + colorful TUI + config."""
import os, sys, json, subprocess, shutil, time
from pathlib import Path
CYBRA  = Path(os.environ["HOME"]) / "CYBRA"
MODS   = CYBRA / "modules"
CTRL   = CYBRA / "controllers"; CTRL.mkdir(exist_ok=True)
SPEC   = CYBRA / "state/taxi_premium_spec.json"
CONF   = CYBRA / "state/taxi_premium_config.json"
MENU   = CYBRA / "taxi_premium"

# ══════════════ CONFIG ══════════════
TOKEN = "0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f"
COMMISSION_PCT = 5
CONF.write_text(json.dumps({
    "cybra_token": TOKEN,
    "commission_pct": COMMISSION_PCT,
    "network": "BSC_MAINNET",
    "chain_id": 56,
    "created_at": time.strftime("%FT%TZ"),
}, indent=2, ensure_ascii=False))

# ══════════════ BODY TEMPLATES ══════════════
MAP_BODY = r'''
CONF="$CYBRA/state/taxi_premium_config.json"
case "$ACTION" in
  add|mark)
    ID="${1:-}"; LAT="${2:-0}"; LON="${3:-0}"; NOTE="${4:-order}"
    [ -z "$ID" ] && { echo "usage: $0 add <id> <lat> <lon> [note]"; exit 1; }
    redis-cli hset "cybra:taxi:map:markers" "$ID" "$LAT,$LON,$NOTE,$(date -u +%FT%TZ)" >/dev/null
    echo "📍 marker $ID @ $LAT,$LON ($NOTE)"
    ;;
  zones)
    ID="${1:-}"; LAT="${2:-0}"; LON="${3:-0}"; R="${4:-200}"; REASON="${5:-residential}"
    [ -z "$ID" ] && { echo "usage: $0 zones <id> <lat> <lon> [radius_m] [reason]"; exit 1; }
    redis-cli hset "cybra:taxi:map:zones" "$ID" "$LAT,$LON,$R,$REASON" >/dev/null
    echo "🚫 avoid zone $ID @ $LAT,$LON r=${R}m ($REASON)"
    ;;
  near)
    LAT="${1:-0}"; LON="${2:-0}"; MAX_KM="${3:-5}"
    echo "════ ${MODULE_LABEL} (near) ════"
    echo "  origin: $LAT,$LON  radius: ${MAX_KM}km"
    redis-cli hgetall cybra:taxi:map:markers 2>/dev/null | paste - - | while read k v; do
      echo "    $k → $v"
    done
    ;;
  set)
    KEY="${1:-}"; VAL="${2:-}"
    [ -z "$KEY" ] && { echo "usage: $0 set <pref> <value>"; exit 1; }
    redis-cli hset "cybra:taxi:pref:${MODULE_CAT}" "$KEY" "$VAL" >/dev/null
    echo "✅ ${MODULE_CAT}: $KEY = $VAL"
    ;;
  enable|disable)
    STATE=$([ "$ACTION" = "enable" ] && echo "1" || echo "0")
    redis-cli set "cybra:taxi:pref:${MODULE_CAT}:enabled" "$STATE" >/dev/null
    echo "✅ ${MODULE_CAT} ${ACTION}d"
    ;;
  show)
    echo "════ ${MODULE_LABEL} ════"
    redis-cli hgetall "cybra:taxi:pref:${MODULE_CAT}" 2>/dev/null | paste - -
    echo "  enabled: $(redis-cli get "cybra:taxi:pref:${MODULE_CAT}:enabled" 2>/dev/null || echo 0)"
    ;;
  list|*)
    echo "════ ${MODULE_LABEL} ════"
    echo "  markers: $(redis-cli hlen cybra:taxi:map:markers 2>/dev/null || echo 0)"
    echo "  zones:   $(redis-cli hlen cybra:taxi:map:zones 2>/dev/null || echo 0)"
    echo "  hint: $0 add <id> <lat> <lon> | zones <id> <lat> <lon> <r> <reason> | near <lat> <lon> [km] | set/show"
    ;;
esac
'''

MEDIA_BODY = r'''
case "$ACTION" in
  record|start)
    DUR="${1:-10}"
    OUT="$CYBRA/evidence/video_$(date +%s).mp4"
    mkdir -p "$CYBRA/evidence"
    if command -v termux-camera-record >/dev/null 2>&1; then
      echo "🎥 recording ${DUR}s → $OUT"
      termux-camera-record -c 0 -d "$DUR" -o "$OUT" && ls -lh "$OUT" && echo "✅ saved"
    else
      echo "❌ termux-api not installed"
      echo "   pkg install termux-api  +  install Termux:API from F-Droid"
    fi
    ;;
  photo)
    OUT="$CYBRA/evidence/photo_$(date +%s).jpg"; mkdir -p "$CYBRA/evidence"
    if command -v termux-camera-photo >/dev/null 2>&1; then
      termux-camera-photo -c 0 "$OUT" && ls -lh "$OUT" && echo "✅ saved"
    else echo "❌ termux-api not installed"; fi
    ;;
  play)
    FILE="${1:-}"
    [ -z "$FILE" ] && { echo "usage: $0 play <file>"; exit 1; }
    if command -v termux-media-player >/dev/null 2>&1; then
      termux-media-player play "$FILE" && echo "▶ playing: $FILE"
    else echo "❌ termux-media-player missing (termux-api)"; fi
    ;;
  stop)
    command -v termux-media-player >/dev/null 2>&1 && termux-media-player stop 2>/dev/null
    echo "⏹ stopped"
    ;;
  list|*)
    echo "════ ${MODULE_LABEL} ════"
    echo "  media files in evidence/:"
    ls -lh "$CYBRA/evidence"/video_*.mp4 "$CYBRA/evidence"/photo_*.jpg 2>/dev/null | tail -10
    echo ""
    echo "  hint: $0 record [sec] | photo | play <file> | stop"
    ;;
esac
'''

PAYMENT_BODY = r'''
CONF="$CYBRA/state/taxi_premium_config.json"
TOKEN=$(python3 -c "import json;print(json.load(open('$CONF'))['cybra_token'])" 2>/dev/null || echo "0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f")
COMMISSION=$(python3 -c "import json;print(json.load(open('$CONF'))['commission_pct'])" 2>/dev/null || echo 5)
case "$ACTION" in
  instant|transfer)
    FROM="${1:-}"; TO="${2:-}"; AMOUNT="${3:-}"
    [ -z "$FROM" ] || [ -z "$TO" ] || [ -z "$AMOUNT" ] && { echo "usage: $0 instant <from> <to> <amount>"; exit 1; }
    RID="PAY-$(date +%s)"
    redis-cli hset "cybra:taxi:payment:data" "$RID" "from=$FROM,to=$TO,amount=$AMOUNT,status=queued" >/dev/null
    echo "💳 card→card: $FROM → $TO  $AMOUNT"
    echo "  pay_id: $RID  status: queued"
    echo "  ⚠️ Real bank card transfer requires PSP (LiqPay/Fondy/Stripe)"
    ;;
  commission)
    AMOUNT="${1:-}"
    [ -z "$AMOUNT" ] && { echo "usage: $0 commission <ride_amount>"; exit 1; }
    FEE=$(awk "BEGIN{printf \"%.2f\", $AMOUNT * $COMMISSION / 100}")
    NET=$(awk "BEGIN{printf \"%.2f\", $AMOUNT - $FEE}")
    RID="COM-$(date +%s)"
    redis-cli hset "cybra:taxi:commission:data" "$RID" "amount=$AMOUNT,fee=$FEE,net=$NET,token=$TOKEN,status=pending" >/dev/null
    echo "════ commission ${COMMISSION}% ════"
    echo "  ride:   $AMOUNT"
    echo "  fee:    $FEE  →  CYBRA token $TOKEN"
    echo "  driver: $NET"
    echo "  ref:    $RID"
    echo "  ⚠️ On-chain transfer needs wallet + RPC"
    ;;
  contract)
    AMOUNT="${1:-}"; DRIVER="${2:-}"; RIDER="${3:-}"
    [ -z "$AMOUNT" ] && { echo "usage: $0 contract <amount> <driver> <rider>"; exit 1; }
    OUT=$(bash "$CYBRA/bin/cybra_contract_create.sh" "$RIDER" "$DRIVER" "$AMOUNT" "CYBRA" 2>/dev/null)
    [ -z "$OUT" ] && OUT=$(bash "$CYBRA/cybra_contract_cli.sh" create "$RIDER" "$DRIVER" "$AMOUNT" "CYBRA" 2>/dev/null)
    echo "$OUT"
    echo "  📝 Підписати у гаманці: відкрий contract у MetaMask"
    ;;
  list|*)
    echo "════ ${MODULE_LABEL} ════"
    echo "  token:      $TOKEN"
    echo "  commission: ${COMMISSION}%"
    echo "  instant:    $0 instant <from> <to> <amount>"
    echo "  commission: $0 commission <ride_amount>"
    echo "  contract:   $0 contract <amount> <driver> <rider>"
    ;;
esac
'''

WALLET_BODY = r'''
case "$ACTION" in
  connect|add)
    ADDR="${1:-}"; ROLE="${2:-rider}"
    [ -z "$ADDR" ] && { echo "usage: $0 connect <address> [rider|driver|both]"; exit 1; }
    redis-cli hset "cybra:taxi:wallet:data" "$ADDR" "role=$ROLE,at=$(date -u +%FT%TZ)" >/dev/null
    echo "👛 connected: $ADDR ($ROLE)"
    ;;
  list)
    echo "════ wallets ════"
    redis-cli hgetall cybra:taxi:wallet:data 2>/dev/null | paste - - | while read a i; do
      echo "  $a  ($i)"
    done
    ;;
  balance)
    ADDR="${1:-}"
    [ -z "$ADDR" ] && { echo "usage: $0 balance <address>"; exit 1; }
    echo "════ balance $ADDR ════"
    echo "  CYBRA: $(redis-cli get "cybra:wallet:$ADDR:cybra" 2>/dev/null || echo 0)"
    echo "  BNB:   $(redis-cli get "cybra:wallet:$ADDR:bnb" 2>/dev/null || echo 0)"
    echo "  ⚠️ On-chain balance: needs RPC (bin/cybra_node.sh)"
    ;;
  remove)
    ADDR="${1:-}"; [ -z "$ADDR" ] && exit 1
    redis-cli hdel cybra:taxi:wallet:data "$ADDR" >/dev/null
    echo "✅ removed: $ADDR"
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 connect <addr> [role] | list | balance <addr> | remove <addr>"
    ;;
esac
'''

PRICE_BODY = r'''
CONF="$CYBRA/state/taxi_premium_config.json"
case "$ACTION" in
  offer)
    RID="${1:-}"; AMOUNT="${2:-}"
    [ -z "$RID" ] || [ -z "$AMOUNT" ] && { echo "usage: $0 offer <ride_id> <amount>"; exit 1; }
    redis-cli hset "cybra:taxi:price:negotiate:$RID" "client_offer=$AMOUNT,ts=$(date -u +%FT%TZ)" >/dev/null
    echo "💵 client offer $AMOUNT → $RID"
    ;;
  counter)
    RID="${1:-}"; AMOUNT="${2:-}"
    [ -z "$RID" ] || [ -z "$AMOUNT" ] && { echo "usage: $0 counter <ride_id> <amount>"; exit 1; }
    redis-cli hset "cybra:taxi:price:negotiate:$RID" "driver_ask=$AMOUNT,ts=$(date -u +%FT%TZ)" >/dev/null
    echo "💵 driver counter $AMOUNT → $RID"
    ;;
  accept)
    RID="${1:-}"; WHO="${2:-client}"
    [ -z "$RID" ] && exit 1
    redis-cli hset "cybra:taxi:price:negotiate:$RID" "accepted_by=$WHO,at=$(date -u +%FT%TZ)" >/dev/null
    echo "✅ $RID accepted by $WHO"
    ;;
  per_km)
    WHO="${1:-client}"; PRICE="${2:-}"
    [ -z "$PRICE" ] && { echo "usage: $0 per_km <client|driver> <price>"; exit 1; }
    redis-cli hset "cybra:taxi:price:perkm" "$WHO" "$PRICE" >/dev/null
    echo "✅ per-km [$WHO]: $PRICE"
    ;;
  show)
    RID="${1:-}"
    if [ -n "$RID" ]; then
      echo "════ negotiate $RID ════"
      redis-cli hgetall "cybra:taxi:price:negotiate:$RID" 2>/dev/null | paste - -
    else
      echo "════ per_km ════"
      redis-cli hgetall cybra:taxi:price:perkm 2>/dev/null | paste - -
    fi
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 offer <ride> <amt> | counter <ride> <amt> | accept <ride> [who] | per_km <who> <price> | show [ride]"
    ;;
esac
'''

MATCH_BODY = r'''
case "$ACTION" in
  interests)
    WHO="${1:-}"; shift 2>/dev/null || true
    [ -z "$WHO" ] && { echo "usage: $0 interests <id> <tag1> [tag2] ..."; exit 1; }
    redis-cli del "cybra:taxi:interests:$WHO" >/dev/null
    for tag in "$@"; do
      redis-cli sadd "cybra:taxi:interests:$WHO" "$tag" >/dev/null
    done
    echo "✅ interests set for $WHO: $*"
    ;;
  match)
    RID="${1:-}"
    [ -z "$RID" ] && { echo "usage: $0 match <rider_id>"; exit 1; }
    echo "════ AI match: rider $RID ════"
    RI=$(redis-cli smembers "cybra:taxi:interests:$RID" 2>/dev/null)
    if [ -z "$RI" ]; then echo "  no interests set"; exit 0; fi
    echo "  rider interests: $(echo $RI | tr '\n' ' ')"
    BEST=""; BEST_SC=0
    for D in $(redis-cli keys "cybra:taxi:interests:*" 2>/dev/null | grep -v ":$RID$"); do
      DID=$(basename "$D" | sed 's/^cybra:taxi:interests://')
      DI=$(redis-cli smembers "$D" 2>/dev/null)
      [ -z "$DI" ] && continue
      SC=0
      for t in $RI; do echo "$DI" | grep -qw "$t" && SC=$((SC+1)); done
      if [ "$SC" -gt "$BEST_SC" ]; then BEST_SC=$SC; BEST=$DID; fi
    done
    if [ -n "$BEST" ]; then
      redis-cli hset cybra:taxi:match:data "$RID" "driver=$BEST,overlap=$BEST_SC" >/dev/null
      echo "  ✅ best: $BEST (shared: $BEST_SC)"
    else
      echo "  no matches"
    fi
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 interests <id> <tag1> <tag2> ... | match <rider_id>"
    echo "  NOTE: rating/comments NOT used (per spec)"
    ;;
esac
'''

RATING_BODY = r'''
case "$ACTION" in
  add)
    WHO="${1:-}"; SC="${2:-}"; shift 2>/dev/null || true
    COMMENT="$*"
    [ -z "$WHO" ] || [ -z "$SC" ] && { echo "usage: $0 add <who> <1-5> [comment]"; exit 1; }
    RID="R-$(date +%s)"
    redis-cli hset cybra:taxi:rating:data "$RID" "$WHO|score=$SC|$COMMENT|$(date -u +%FT%TZ)" >/dev/null
    echo "⭐ saved ($RID) — does NOT affect dispatch/AI"
    ;;
  view|list|*)
    WHO="${1:-}"
    echo "════ ${MODULE_LABEL} ════"
    redis-cli hgetall cybra:taxi:rating:data 2>/dev/null | paste - - | while read k v; do
      if [ -z "$WHO" ] || echo "$v" | grep -q "^$WHO|"; then
        echo "  $k: $v"
      fi
    done
    echo "  NOTE: rating only for review — does NOT affect driver work"
    ;;
esac
'''

ECO_BODY = r'''
case "$ACTION" in
  sync)
    cd "$CYBRA"
    git add state/taxi_premium_spec.json state/taxi_premium_config.json \
            modules/module_2[4-5][0-9]_* controllers/premium_module_*.ctrl.sh \
            taxi_premium bin/cybra_taxi_premium_deploy.py 2>/dev/null
    git commit -m "eco: sync taxi_premium to all nodes" 2>&1 | head -2
    git push origin main 2>&1 | tail -2
    echo "✅ pushed — other devices pull next cycle"
    ;;
  status|*)
    echo "════ ${MODULE_LABEL} ════"
    echo "  device:  $(hostname)"
    echo "  nodes:   $(ls "$CYBRA/nodes/heartbeats/" 2>/dev/null | wc -l)"
    echo "  HEAD:    $(git -C "$CYBRA" log -1 --format='%h %s' 2>/dev/null)"
    echo "  hint:    $0 sync  — push to all nodes via git"
    ;;
esac
'''

THEME_BODY = r'''
case "$ACTION" in
  set)
    NAME="${1:-bright}"
    redis-cli set "cybra:taxi:ui:theme" "$NAME" >/dev/null
    echo "🎨 theme: $NAME"
    ;;
  show|*)
    echo "════ ${MODULE_LABEL} ════"
    echo "  current: $(redis-cli get cybra:taxi:ui:theme 2>/dev/null || echo default)"
    echo "  hint: $0 set <bright|neon|sunset>"
    ;;
esac
'''

# ══════════════ MODULE MAP ══════════════
MODULES = [
    (240, "virtual_map",        "map",     "list",  MAP_BODY),
    (241, "map_zones",          "map",     "list",  MAP_BODY),
    (242, "route_preference",   "map",     "show",  MAP_BODY),
    (243, "parking_priority",   "map",     "show",  MAP_BODY),
    (244, "video_recorder",     "media",   "list",  MEDIA_BODY),
    (245, "media_player",       "media",   "list",  MEDIA_BODY),
    (246, "payment_instant",    "payment", "list",  PAYMENT_BODY),
    (247, "payment_commission", "payment", "list",  PAYMENT_BODY),
    (248, "payment_contract",   "payment", "list",  PAYMENT_BODY),
    (249, "wallet_connect",     "wallet",  "list",  WALLET_BODY),
    (250, "wallet_list",        "wallet",  "list",  WALLET_BODY),
    (251, "wallet_balance",     "wallet",  "list",  WALLET_BODY),
    (252, "price_adaptive",     "price",   "show",  PRICE_BODY),
    (253, "price_per_km",       "price",   "show",  PRICE_BODY),
    (254, "ai_match",           "ai",      "list",  MATCH_BODY),
    (255, "ai_zone_optimize",   "map",     "list",  MAP_BODY),
    (256, "rating_view",        "rating",  "list",  RATING_BODY),
    (257, "rating_comments",    "rating",  "list",  RATING_BODY),
    (258, "eco_global",         "eco",     "status", ECO_BODY),
    (259, "ui_theme",           "ui",      "show",  THEME_BODY),
]

MAIN_HEADER = '''#!/data/data/com.termux/files/usr/bin/bash
# module_{nn}: {name} ({cat}) — taxi_premium
# generated {ts}
set -u
CYBRA="${{CYBRA:-$HOME/CYBRA}}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${{1:-{default_action}}}"; shift $(( $# > 0 ? 1 : 0 ))
MODULE_LABEL="{name}"
MODULE_CAT="{cat}"
'''

def find_or_create(n, name):
    for pat in [f"module_{n:03d}_*", f"module_{n}_*"]:
        for d in MODS.glob(pat):
            if d.is_dir(): return d
    d = MODS / f"module_{n:03d}_{name}"
    d.mkdir(parents=True, exist_ok=True)
    return d

def main():
    print("═══ TAXI PREMIUM DEPLOY ═══")
    ts = time.strftime("%FT%TZ")
    created, failed = 0, 0

    for n, name, cat, default, body in MODULES:
        d = find_or_create(n, name)
        main_sh = d / "main.sh"
        content = MAIN_HEADER.format(nn=f"{n:03d}", name=name, cat=cat, ts=ts, default_action=default) + body
        main_sh.write_text(content)
        os.chmod(main_sh, 0o755)
        if subprocess.run(["bash","-n",str(main_sh)],capture_output=True).returncode == 0:
            created += 1
        else:
            failed += 1
            print(f"  ❌ {n}: {main_sh}")

        # ctrl
        ctrl = CTRL / f"premium_module_{n:03d}.ctrl.sh"
        ctrl.write_text(f'''#!/data/data/com.termux/files/usr/bin/bash
set -u
M="$1"; shift
[ -f "$M" ] || {{ echo "missing"; exit 2; }}
[ $# -gt 0 ] && A=("$@") || A=("list")
bash "$M" "${{A[@]}}" </dev/null 2>&1
exit $?
''')
        os.chmod(ctrl, 0o755)

    print(f"✅ modules: {created}/{len(MODULES)}  (failed: {failed})")

    # spec
    spec = {n: {"name": name, "category": cat, "default_action": default}
            for n, name, cat, default, _ in MODULES}
    SPEC.write_text(json.dumps({"version": "1.0", "generated": ts, "modules": spec}, indent=2, ensure_ascii=False))
    print(f"✅ spec:    {SPEC}")
    print(f"✅ config:  {CONF}")

    # colorful menu
    menu_content = r'''#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"; cd "$CYBRA" 2>/dev/null || exit 1
G=$'\033[1;32m'; C=$'\033[1;36m'; Y=$'\033[1;33m'; M=$'\033[1;35m'; R=$'\033[0m'
B=$'\033[1m'; D=$'\033[2m'
notify=$(bash "$CYBRA/bin/cybra_notify.sh" bar 2>/dev/null)
markers=$(redis-cli hlen cybra:taxi:map:markers 2>/dev/null || echo 0)
wallets=$(redis-cli hlen cybra:taxi:wallet:data 2>/dev/null || echo 0)
theme=$(redis-cli get cybra:taxi:ui:theme 2>/dev/null || echo default)
while true; do
  clear
  echo -e "${G}╔══════════════════════════════════════════════════════════════════╗${R}"
  echo -e "${G}║  🚕 ${B}CYBRA TAXI PREMIUM${R}   ${D}20 modules · 240-259${R}              ${G}║${R}"
  echo -e "${G}║  ${C}${notify}${R}                                                     ${G}║${R}"
  echo -e "${G}║  ${Y}📍 ${markers}${R}  ${M}👛 ${wallets}${R}  ${C}🎨 ${theme}${R}                              ${G}║${R}"
  echo -e "${G}╚══════════════════════════════════════════════════════════════════╝${R}"
  echo ""
  echo -e "  ${Y}─── 🗺  КАРТИ / ЗОНИ ───${R}"
  echo -e "  ${C}[240]${R} Вірт. карта  ${C}[241]${R} Зони(уник)  ${C}[242]${R} Напрямок  ${C}[243]${R} Парковка"
  echo -e "  ${C}[255]${R} AI-зон-оптимізація"
  echo ""
  echo -e "  ${Y}─── 🎥 МЕДІА ───${R}"
  echo -e "  ${C}[244]${R} Відеореєстратор  ${C}[245]${R} Медіаплеєр"
  echo ""
  echo -e "  ${Y}─── 💰 ОПЛАТА ───${R}"
  echo -e "  ${C}[246]${R} Card→Card  ${C}[247]${R} Комісія 5%→CYBRA  ${C}[248]${R} Контракт"
  echo -e "  ${M}0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f${R}"
  echo ""
  echo -e "  ${Y}─── 👛 ГАМАНЦІ ───${R}"
  echo -e "  ${C}[249]${R} Приєднати  ${C}[250]${R} Список  ${C}[251]${R} Баланс"
  echo ""
  echo -e "  ${Y}─── 💵 ЦІНИ ───${R}"
  echo -e "  ${C}[252]${R} Адаптивна  ${C}[253]${R} Ціна за км"
  echo ""
  echo -e "  ${Y}─── 🤖 AI ───${R}"
  echo -e "  ${C}[254]${R} AI-підбір (за інтересами)"
  echo ""
  echo -e "  ${Y}─── ⭐ РЕЙТИНГ ${D}(не впливає на роботу)${R}${Y} ───${R}"
  echo -e "  ${C}[256]${R} Перегляд  ${C}[257]${R} Коментарі"
  echo ""
  echo -e "  ${Y}─── 🌍 СИСТЕМА ───${R}"
  echo -e "  ${C}[258]${R} Eco sync  ${C}[259]${R} UI-тема  ${C}[0]${R} Вихід"
  echo ""
  read -r -p "  ${B}Вибір:${R} " c
  case "$c" in
    240|241|242|243|244|245|246|247|248|249|250|251|252|253|254|255|256|257|258|259)
      DIR=$(find "$CYBRA/modules" -maxdepth 1 -type d -name "module_${c}_*" 2>/dev/null | head -1)
      CTRL="$CYBRA/controllers/premium_module_${c}.ctrl.sh"
      [ -f "$CTRL" ] && [ -n "$DIR" ] && bash "$CTRL" "$DIR/main.sh"
      read -r -p "Enter..." _ ;;
    0|q|Q) exit 0 ;;
  esac
done
'''
    MENU.write_text(menu_content)
    os.chmod(MENU, 0o755)
    if subprocess.run(["bash","-n",str(MENU)],capture_output=True).returncode == 0:
        print(f"✅ menu:    {MENU}")
    else:
        print(f"❌ menu syntax broken")

    # test
    print("\n── TEST 5 ──")
    for n in [240, 244, 247, 249, 254]:
        d = next((p for p in MODS.glob(f"module_{n}_*") if p.is_dir()), None)
        if not d: continue
        r = subprocess.run(["bash",str(d/"main.sh"),"list"], capture_output=True, text=True, timeout=10, input="")
        ok = "✅" if r.returncode == 0 and len(r.stdout.splitlines()) >= 2 else "❌"
        print(f"  [{n}] {ok}  {r.stdout.splitlines()[0] if r.stdout else 'empty'}")

    print(f"\n  🚕 launch: ~/CYBRA/taxi_premium")
    print(f"  📋 config: {CONF}  (token={TOKEN}, commission={COMMISSION_PCT}%)")

if __name__ == "__main__":
    main()
