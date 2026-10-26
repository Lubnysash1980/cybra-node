#!/usr/bin/env python3
"""ULTRA taxi: 20 модулів 260-279.
   - Peer discovery БЕЗ GPS: camera/QR, cell-tower, manual marker, BLE (scan), WiFi (scan)
   - Location fallback fusion
   - 100% state gate
   - i18n 7 мов (en, uk, es, de, fr, ar, zh)
   - Voice, AI assistant, SOS, live share
"""
import os, sys, json, subprocess, time
from pathlib import Path
CYBRA  = Path(os.environ["HOME"]) / "CYBRA"
MODS   = CYBRA / "modules"
CTRL   = CYBRA / "controllers"
I18N   = CYBRA / "state/taxi/i18n"
SPEC   = CYBRA / "state/taxi_ultra_spec.json"
I18N.mkdir(parents=True, exist_ok=True)
CTRL.mkdir(exist_ok=True)

# ════════ i18n ════════
STRINGS = {
    "en": {"welcome":"Welcome to CYBRA Taxi","pickup":"Pickup","dropoff":"Dropoff","price":"Price",
           "accept":"Accept","decline":"Decline","in_progress":"In progress","completed":"Completed",
           "driver":"Driver","rider":"Rider","rating":"Rating","comment":"Comment","offline":"Offline",
           "gps_off":"GPS disabled — using fallback","scan_qr":"Scan QR to find driver",
           "sos":"Emergency SOS","share":"Share live trip","history":"History","wallet":"Wallet",
           "connecting":"Connecting...","matched":"Matched!"},
    "uk": {"welcome":"Вітаємо в CYBRA Таксі","pickup":"Звідки","dropoff":"Куди","price":"Ціна",
           "accept":"Прийняти","decline":"Відхилити","in_progress":"В дорозі","completed":"Завершено",
           "driver":"Водій","rider":"Пасажир","rating":"Рейтинг","comment":"Коментар","offline":"Офлайн",
           "gps_off":"GPS вимкнено — працює fallback","scan_qr":"Скануй QR щоб знайти водія",
           "sos":"Екстрений SOS","share":"Поділитись поїздкою","history":"Історія","wallet":"Гаманець",
           "connecting":"З'єднання...","matched":"Знайдено!"},
    "es": {"welcome":"Bienvenido a CYBRA Taxi","pickup":"Recogida","dropoff":"Destino","price":"Precio",
           "accept":"Aceptar","decline":"Rechazar","in_progress":"En camino","completed":"Completado",
           "driver":"Conductor","rider":"Pasajero","rating":"Calificación","comment":"Comentario","offline":"Sin conexión",
           "gps_off":"GPS desactivado — usando fallback","scan_qr":"Escanea QR para encontrar conductor",
           "sos":"SOS de emergencia","share":"Compartir viaje","history":"Historial","wallet":"Billetera",
           "connecting":"Conectando...","matched":"¡Emparejado!"},
    "de": {"welcome":"Willkommen bei CYBRA Taxi","pickup":"Abholung","dropoff":"Ziel","price":"Preis",
           "accept":"Annehmen","decline":"Ablehnen","in_progress":"Unterwegs","completed":"Abgeschlossen",
           "driver":"Fahrer","rider":"Fahrgast","rating":"Bewertung","comment":"Kommentar","offline":"Offline",
           "gps_off":"GPS aus — Fallback aktiv","scan_qr":"QR scannen um Fahrer zu finden",
           "sos":"Notfall SOS","share":"Fahrt teilen","history":"Verlauf","wallet":"Geldbörse",
           "connecting":"Verbinde...","matched":"Gefunden!"},
    "fr": {"welcome":"Bienvenue à CYBRA Taxi","pickup":"Prise en charge","dropoff":"Destination","price":"Prix",
           "accept":"Accepter","decline":"Refuser","in_progress":"En cours","completed":"Terminé",
           "driver":"Chauffeur","rider":"Passager","rating":"Note","comment":"Commentaire","offline":"Hors ligne",
           "gps_off":"GPS désactivé — fallback actif","scan_qr":"Scannez QR pour trouver le chauffeur",
           "sos":"SOS urgence","share":"Partager le trajet","history":"Historique","wallet":"Portefeuille",
           "connecting":"Connexion...","matched":"Trouvé!"},
    "ar": {"welcome":"مرحبًا بك في CYBRA Taxi","pickup":"نقطة الانطلاق","dropoff":"الوجهة","price":"السعر",
           "accept":"قبول","decline":"رفض","in_progress":"في الطريق","completed":"مكتمل",
           "driver":"السائق","rider":"الراكب","rating":"التقييم","comment":"تعليق","offline":"غير متصل",
           "gps_off":"GPS معطل — استخدام البديل","scan_qr":"امسح QR للعثور على السائق",
           "sos":"SOS طوارئ","share":"مشاركة الرحلة","history":"السجل","wallet":"المحفظة",
           "connecting":"جارٍ الاتصال...","matched":"تم التطابق!"},
    "zh": {"welcome":"欢迎使用 CYBRA 出租车","pickup":"接客","dropoff":"目的地","price":"价格",
           "accept":"接受","decline":"拒绝","in_progress":"行程中","completed":"已完成",
           "driver":"司机","rider":"乘客","rating":"评分","comment":"评论","offline":"离线",
           "gps_off":"GPS 已关闭 — 使用备用定位","scan_qr":"扫描二维码找到司机",
           "sos":"紧急呼救","share":"分享行程","history":"历史","wallet":"钱包",
           "connecting":"连接中...","matched":"已匹配!"},
}
for lang, strings in STRINGS.items():
    (I18N/f"{lang}.json").write_text(json.dumps(strings, ensure_ascii=False, indent=2))

# ════════ Module bodies ════════

PEER_CAMERA = r'''
CONF="$CYBRA/state/taxi_premium_config.json"
case "$ACTION" in
  make-qr)
    RID="${1:-}"
    [ -z "$RID" ] && { echo "usage: $0 make-qr <ride_id>"; exit 1; }
    PAYLOAD="cybra:ride:$RID:$(date +%s)"
    OUT="$CYBRA/evidence/qr_${RID}.png"
    mkdir -p "$CYBRA/evidence"
    if command -v qrencode >/dev/null 2>&1; then
      qrencode -o "$OUT" "$PAYLOAD"
      redis-cli hset cybra:taxi:peer:qr "$RID" "$PAYLOAD" >/dev/null
      echo "✅ QR saved: $OUT"
      echo "   payload: $PAYLOAD"
    else
      echo "❌ qrencode missing: pkg install qrencode"
    fi
    ;;
  scan)
    OUT="$CYBRA/evidence/scan_$(date +%s).jpg"
    if ! command -v termux-camera-photo >/dev/null 2>&1; then
      echo "❌ pkg install termux-api + Termux:API app"; exit 1
    fi
    if ! command -v zbarimg >/dev/null 2>&1; then
      echo "❌ pkg install zbar"; exit 1
    fi
    termux-camera-photo -c 0 "$OUT" 2>/dev/null
    [ -f "$OUT" ] || { echo "❌ photo fail"; exit 1; }
    PAYLOAD=$(zbarimg -q --raw "$OUT" 2>/dev/null | head -1)
    [ -z "$PAYLOAD" ] && { echo "❌ no QR in photo"; exit 1; }
    echo "📷 scanned: $PAYLOAD"
    echo "$PAYLOAD" | grep -q '^cybra:ride:' && {
      RID=$(echo "$PAYLOAD" | cut -d: -f3)
      redis-cli hset cybra:taxi:peer:discovered "$RID" "camera|$(date -u +%FT%TZ)" >/dev/null
      echo "✅ peer found WITHOUT GPS: ride=$RID"
    }
    ;;
  show)
    echo "════ ${MODULE_LABEL} ════"
    redis-cli hgetall cybra:taxi:peer:qr 2>/dev/null | paste - -
    echo "  ─── discovered ───"
    redis-cli hgetall cybra:taxi:peer:discovered 2>/dev/null | paste - -
    echo "  hint: $0 make-qr <ride> | scan"
    ;;
  *) echo "usage: $0 make-qr <ride> | scan | show" ;;
esac
'''

PEER_CELL = r'''
case "$ACTION" in
  scan)
    if ! command -v termux-telephony-cellinfo >/dev/null 2>&1; then
      echo "❌ termux-api missing (pkg install termux-api + app)"
      echo "   fallback: manual marker"
      exit 1
    fi
    INFO=$(termux-telephony-cellinfo 2>/dev/null)
    [ -z "$INFO" ] && { echo "❌ no cell info (no SIM / airplane)"; exit 1; }
    # extract mcc, mnc, cid, lac
    M=$(echo "$INFO" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    if isinstance(d,list): d=d[0]
    print(f\"{d.get('mcc','?')},{d.get('mnc','?')},{d.get('cid','?')},{d.get('lac','?')}\")
except: print('?')
")
    redis-cli hset cybra:taxi:peer:cell "current" "$M|$(date -u +%FT%TZ)" >/dev/null
    echo "📡 cell tower: $M  (GPS-free location fix)"
    ;;
  match)
    RID="${1:-}"
    [ -z "$RID" ] && exit 1
    MY=$(redis-cli hget cybra:taxi:peer:cell current 2>/dev/null | cut -d'|' -f1)
    [ -z "$MY" ] && { echo "❌ run 'scan' first"; exit 1; }
    echo "════ ${MODULE_LABEL} ════"
    echo "  my cell: $MY"
    echo "  → if driver on same tower, they're within ~500m-2km"
    redis-cli hset "cybra:taxi:peer:proximity:$RID" "cell" "$MY" >/dev/null
    echo "✅ proximity claim saved: $RID @ cell $MY"
    ;;
  list|*)
    echo "════ ${MODULE_LABEL} ════"
    redis-cli hget cybra:taxi:peer:cell current 2>/dev/null
    echo "  hint: $0 scan | match <ride_id>"
    ;;
esac
'''

PEER_BLE = r'''
case "$ACTION" in
  scan)
    if ! command -v termux-bluetooth-scan >/dev/null 2>&1 && ! command -v termux-bluetooth-connection >/dev/null 2>&1; then
      echo "❌ termux-api без BT підтримки"
      echo "   BLE-advertising потребує Flutter/native (Android BLE APIs)"
      echo "   Тут тільки: увімкни BT + спробуй 'scan' через bluetoothctl"
    fi
    # Termux fallback: bluetoothctl (якщо pkg install bluez)
    if command -v bluetoothctl >/dev/null 2>&1; then
      timeout 10 bluetoothctl scan on 2>/dev/null | head -5
      echo "✅ BT scan (10s)"
    else
      echo "❌ no BT stack. Options:"
      echo "   a) pkg install bluez"
      echo "   b) BLE native — Flutter (real path)"
    fi
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  BLE peer discovery: NEEDS Flutter/native"
    echo "  Termux: bluetoothctl (basic scan)"
    echo "  hint: $0 scan"
    ;;
esac
'''

PEER_WIFI = r'''
case "$ACTION" in
  scan)
    # Wi-Fi Direct (P2P) — needs native. Termux: scan networks only.
    if command -v termux-wifi-scaninfo >/dev/null 2>&1; then
      termux-wifi-scaninfo 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    for n in d[:10]:
        print(f\"  SSID: {n.get('SSID','?')}  BSSID: {n.get('BSSID','?')}  RSSI: {n.get('RSSI',0)}\")
except Exception as e: print('parse error:', e)
"
    else
      echo "❌ pkg install termux-api + app"
    fi
    ;;
  p2p)
    echo "⚠️ Wi-Fi Direct (P2P) — Flutter plugin only"
    echo "   native: android.net.wifi.p2p.*"
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  Wi-Fi scan: $0 scan"
    echo "  Wi-Fi P2P: needs Flutter"
    ;;
esac
'''

LOCATION_FALLBACK = r'''
case "$ACTION" in
  fix)
    # fusion: try gps → cell → last_known → manual
    SRC=""; LAT=""; LON=""
    # 1. GPS via termux-location
    if command -v termux-location >/dev/null 2>&1; then
      GPS=$(timeout 5 termux-location -p gps 2>/dev/null)
      if [ -n "$GPS" ]; then
        LAT=$(echo "$GPS" | python3 -c "import sys,json;print(json.load(sys.stdin).get('latitude',''))" 2>/dev/null)
        LON=$(echo "$GPS" | python3 -c "import sys,json;print(json.load(sys.stdin).get('longitude',''))" 2>/dev/null)
        [ -n "$LAT" ] && SRC="gps"
      fi
    fi
    # 2. Network-based (wifi/cell)
    if [ -z "$SRC" ] && command -v termux-location >/dev/null 2>&1; then
      NET=$(timeout 5 termux-location -p network 2>/dev/null)
      if [ -n "$NET" ]; then
        LAT=$(echo "$NET" | python3 -c "import sys,json;print(json.load(sys.stdin).get('latitude',''))" 2>/dev/null)
        LON=$(echo "$NET" | python3 -c "import sys,json;print(json.load(sys.stdin).get('longitude',''))" 2>/dev/null)
        [ -n "$LAT" ] && SRC="network"
      fi
    fi
    # 3. Cell tower
    if [ -z "$SRC" ] && command -v termux-telephony-cellinfo >/dev/null 2>&1; then
      CELL=$(timeout 5 termux-telephony-cellinfo 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    if isinstance(d,list): d=d[0]
    print(f\"{d.get('mcc','?')},{d.get('mnc','?')},{d.get('cid','?')}")
except: pass
")
      [ -n "$CELL" ] && { LAT="$CELL"; LON="cell"; SRC="cell"; }
    fi
    # 4. Last known
    if [ -z "$SRC" ]; then
      LAST=$(redis-cli hget cybra:taxi:location:last "any" 2>/dev/null)
      if [ -n "$LAST" ]; then
        LAT=$(echo "$LAST" | cut -d'|' -f1); LON=$(echo "$LAST" | cut -d'|' -f2); SRC="last_known"
      fi
    fi
    if [ -z "$SRC" ]; then
      echo "❌ no location (no GPS, no cell, no last known)"
      echo "   → use 'mark' to set manually"
      exit 1
    fi
    redis-cli hset cybra:taxi:location:last "any" "$LAT|$LON|$SRC|$(date -u +%FT%TZ)" >/dev/null
    echo "📍 fix: $LAT,$LON  (source: $SRC)"
    ;;
  mark)
    LAT="${1:-}"; LON="${2:-}"
    [ -z "$LAT" ] || [ -z "$LON" ] && { echo "usage: $0 mark <lat> <lon>"; exit 1; }
    redis-cli hset cybra:taxi:location:last "any" "$LAT|$LON|manual|$(date -u +%FT%TZ)" >/dev/null
    echo "📍 manual: $LAT,$LON"
    ;;
  show|*)
    echo "════ ${MODULE_LABEL} ════"
    redis-cli hget cybra:taxi:location:last "any" 2>/dev/null | awk -F'|' '{
      print "  lat=" $1 "  lon=" $2 "  src=" $3 "  at=" $4
    }'
    echo "  hint: $0 fix | mark <lat> <lon>"
    ;;
esac
'''

PEER_FUSION = r'''
case "$ACTION" in
  resolve)
    RID="${1:-}"
    [ -z "$RID" ] && exit 1
    echo "════ ${MODULE_LABEL}: $RID ════"
    CONF=0
    echo "  ─── sources ───"
    CAM=$(redis-cli hget cybra:taxi:peer:discovered "$RID" 2>/dev/null)
    [ -n "$CAM" ] && { echo "  ✓ camera: $CAM"; CONF=$((CONF+40)); }
    CELL=$(redis-cli hget "cybra:taxi:peer:proximity:$RID" cell 2>/dev/null)
    [ -n "$CELL" ] && { echo "  ✓ cell: $CELL"; CONF=$((CONF+25)); }
    LOC=$(redis-cli hget cybra:taxi:location:last any 2>/dev/null)
    [ -n "$LOC" ] && { echo "  ✓ location: $LOC"; CONF=$((CONF+20)); }
    MANUAL=$(redis-cli hget "cybra:taxi:peer:manual:$RID" any 2>/dev/null)
    [ -n "$MANUAL" ] && { echo "  ✓ manual: $MANUAL"; CONF=$((CONF+15)); }
    echo "  ─── confidence: $CONF/100 ───"
    if [ "$CONF" -ge 40 ]; then
      redis-cli hset "cybra:taxi:peer:matched:$RID" "confidence" "$CONF" >/dev/null
      redis-cli hset "cybra:peer:matched:$RID" "confidence" "$CONF" >/dev/null
      echo "  ✅ MATCH (>=40%)"
    else
      echo "  ⚠️ low confidence — need camera QR or manual"
    fi
    ;;
  set-manual)
    RID="${1:-}"; LAT="${2:-}"; LON="${3:-}"
    [ -z "$RID" ] && exit 1
    redis-cli hset "cybra:taxi:peer:manual:$RID" any "$LAT,$LON,$(date -u +%FT%TZ)" >/dev/null
    echo "✅ manual peer marker: $RID @ $LAT,$LON"
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  peer fusion: resolve <ride> | set-manual <ride> <lat> <lon>"
    ;;
esac
'''

STATE_100 = r'''
case "$ACTION" in
  check)
    echo "════ ${MODULE_LABEL}: 100% state gate ════"
    SCORE=0; MAX=0
    chk() { MAX=$((MAX+1)); if eval "$2" >/dev/null 2>&1; then SCORE=$((SCORE+1)); echo "  ✅ $1"; else echo "  ❌ $1"; fi; }
    chk "redis PONG"         "redis-cli ping | grep -q PONG"
    chk "parliament online"  "pm2 jlist | python3 -c 'import sys,json;d=json.load(sys.stdin);sys.exit(0 if any(p[\"name\"]==\"parliament\" and p[\"pm2_env\"][\"status\"]==\"online\" for p in d) else 1)'"
    chk "menu-worker online" "pm2 jlist | python3 -c 'import sys,json;d=json.load(sys.stdin);sys.exit(0 if any(p[\"name\"]==\"menu-worker\" and p[\"pm2_env\"][\"status\"]==\"online\" for p in d) else 1)'"
    chk "taxi-events online" "pm2 jlist | python3 -c 'import sys,json;d=json.load(sys.stdin);sys.exit(0 if any(p[\"name\"]==\"taxi-events\" and p[\"pm2_env\"][\"status\"]==\"online\" for p in d) else 1)'"
    chk "config token"       "[ -f \"$CYBRA/state/taxi_premium_config.json\" ]"
    chk "i18n en+uk"         "[ -f \"$CYBRA/state/taxi/i18n/en.json\" ] && [ -f \"$CYBRA/state/taxi/i18n/uk.json\" ]"
    chk "modules 240-259"    "[ $(ls -d $CYBRA/modules/module_2[45][0-9]_* 2>/dev/null | wc -l) -ge 20 ]"
    chk "modules 260-279"    "[ $(ls -d $CYBRA/modules/module_2[67][0-9]_* 2>/dev/null | wc -l) -ge 15 ]"
    chk "location fallback"  "[ -x \"$CYBRA/modules/module_265_location_fallback/main.sh\" ]"
    chk "peer camera"        "[ -x \"$CYBRA/modules/module_260_peer_camera/main.sh\" ]"
    PCT=$((SCORE * 100 / MAX))
    echo ""
    echo "  ─── SCORE: $SCORE/$MAX ($PCT%) ───"
    redis-cli hset cybra:taxi:state "$(date +%s)" "score=$SCORE,max=$MAX,pct=$PCT" >/dev/null
    redis-cli set cybra:taxi:state:current "$PCT" >/dev/null
    if [ "$PCT" -eq 100 ]; then
      echo "  🎉 100% READY"
      redis-cli set cybra:taxi:state:ready "1" >/dev/null
      exit 0
    fi
    exit 1
    ;;
  gate)
    READY=$(redis-cli get cybra:taxi:state:ready 2>/dev/null || echo 0)
    PCT=$(redis-cli get cybra:taxi:state:current 2>/dev/null || echo 0)
    if [ "$READY" = "1" ]; then echo "✅ ride allowed ($PCT%)"; exit 0; fi
    echo "❌ ride blocked ($PCT% < 100%)"
    exit 1
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 check | gate"
    ;;
esac
'''

I18N_LOADER = r'''
case "$ACTION" in
  set)
    LANG="${1:-en}"
    F="$CYBRA/state/taxi/i18n/$LANG.json"
    [ -f "$F" ] || { echo "❌ lang $LANG not found"; echo "  available: $(ls $CYBRA/state/taxi/i18n/ 2>/dev/null | sed 's/\.json//g' | tr '\n' ' ')"; exit 1; }
    redis-cli set cybra:taxi:i18n:lang "$LANG" >/dev/null
    echo "🌐 lang: $LANG"
    ;;
  get)
    KEY="${1:-welcome}"
    LANG=$(redis-cli get cybra:taxi:i18n:lang 2>/dev/null || echo en)
    F="$CYBRA/state/taxi/i18n/$LANG.json"
    V=$(python3 -c "import json;d=json.load(open('$F'));print(d.get('$KEY', '[' + '$KEY' + ' not found]'))" 2>/dev/null)
    echo "$V"
    ;;
  list)
    echo "════ langs ════"
    ls "$CYBRA/state/taxi/i18n/" 2>/dev/null | sed 's/\.json//g' | nl
    echo "  current: $(redis-cli get cybra:taxi:i18n:lang 2>/dev/null || echo en)"
    ;;
  dump)
    LANG=$(redis-cli get cybra:taxi:i18n:lang 2>/dev/null || echo en)
    F="$CYBRA/state/taxi/i18n/$LANG.json"
    cat "$F" | python3 -m json.tool
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 set <lang> | get <key> | list | dump"
    echo "  langs: en uk es de fr ar zh"
    ;;
esac
'''

VOICE = r'''
case "$ACTION" in
  listen)
    if command -v termux-speech-to-text >/dev/null 2>&1; then
      echo "🎤 listening..."
      TXT=$(timeout 10 termux-speech-to-text 2>/dev/null)
      [ -n "$TXT" ] && { echo "  heard: $TXT"; redis-cli set cybra:taxi:voice:last "$TXT" >/dev/null; }
    else
      echo "❌ termux-api missing (pkg install termux-api + app)"
    fi
    ;;
  say)
    TXT="${1:-}"
    [ -z "$TXT" ] && exit 1
    command -v termux-tts-speak >/dev/null 2>&1 && termux-tts-speak "$TXT" && echo "🔊 said: $TXT"
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 listen | say <text>"
    ;;
esac
'''

AI_ASSIST = r'''
CONF="$CYBRA/state/taxi_premium_config.json"
case "$ACTION" in
  ask)
    Q="$*"
    [ -z "$Q" ] && exit 1
    echo "════ ${MODULE_LABEL}: $Q ════"
    # try local AI first
    LOCAL="$CYBRA/modules/module_19_contract_tui_menu/bin/cybra_local_ai.sh"
    if [ -x "$LOCAL" ]; then
      CYBRA_MOD19_ROOT="$CYBRA/modules/module_19_contract_tui_menu" bash "$LOCAL" ask "$Q" 2>/dev/null
    else
      echo "  (offline fallback)"
      echo "  My purpose: help with taxi rides, prices, routes, wallets."
    fi
    ;;
  suggest_price)
    RID="${1:-}"; KM="${2:-5}"
    [ -z "$RID" ] && exit 1
    BASE=$(awk "BEGIN{print $KM * 15}")
    LOW=$(awk "BEGIN{print $BASE * 0.8}")
    HIGH=$(awk "BEGIN{print $BASE * 1.2}")
    echo "════ price suggestion: $RID, ${KM}km ════"
    echo "  range: $LOW - $HIGH (base $BASE)"
    redis-cli hset "cybra:taxi:price:suggest:$RID" "low=$LOW,base=$BASE,high=$HIGH,km=$KM" >/dev/null
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 ask <question> | suggest_price <ride> <km>"
    ;;
esac
'''

SOS = r'''
case "$ACTION" in
  trigger)
    REASON="${1:-emergency}"
    TS=$(date -u +%FT%TZ)
    LOC=$(redis-cli hget cybra:taxi:location:last any 2>/dev/null | cut -d'|' -f1,2)
    redis-cli rpush cybra:taxi:sos "{\"ts\":\"$TS\",\"reason\":\"$REASON\",\"loc\":\"$LOC\"}" >/dev/null
    redis-cli rpush cybra:parliament:queue "{\"id\":\"sos-$TS\",\"action\":\"sos_alert\",\"topic\":\"taxi_sos\",\"reason\":\"$REASON\",\"loc\":\"$LOC\",\"ts\":\"$TS\"}" >/dev/null
    echo "🚨 SOS TRIGGERED"
    echo "   reason: $REASON"
    echo "   location: $LOC"
    echo "   sent to parliament + parliament:queue"
    ;;
  list)
    echo "════ SOS history ════"
    redis-cli lrange cybra:taxi:sos 0 -1 2>/dev/null | tail -10
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 trigger [reason] | list"
    ;;
esac
'''

SHARE = r'''
case "$ACTION" in
  start)
    RID="${1:-}"
    [ -z "$RID" ] && exit 1
    TOKEN=$(head -c 8 /dev/urandom | xxd -p)
    redis-cli hset "cybra:taxi:share:$TOKEN" "ride" "$RID" >/dev/null
    redis-cli hset "cybra:taxi:share:$TOKEN" "ts" "$(date -u +%FT%TZ)" >/dev/null
    redis-cli set "cybra:taxi:share:ride:$RID" "$TOKEN" >/dev/null
    echo "════ ${MODULE_LABEL} ════"
    echo "  share_token: $TOKEN"
    echo "  url:  https://cybra.app/t/$TOKEN"
    echo "  ride: $RID"
    ;;
  status)
    TOKEN="${1:-}"
    [ -z "$TOKEN" ] && exit 1
    echo "════ share $TOKEN ════"
    redis-cli hgetall "cybra:taxi:share:$TOKEN" 2>/dev/null | paste - -
    ;;
  stop)
    RID="${1:-}"
    [ -z "$RID" ] && exit 1
    TOKEN=$(redis-cli get "cybra:taxi:share:ride:$RID" 2>/dev/null)
    [ -n "$TOKEN" ] && redis-cli del "cybra:taxi:share:$TOKEN" >/dev/null
    redis-cli del "cybra:taxi:share:ride:$RID" >/dev/null
    echo "⏹ share stopped: $RID"
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 start <ride> | status <token> | stop <ride>"
    ;;
esac
'''

APP_METRICS = r'''
case "$ACTION" in
  record)
    KEY="${1:-}"; VAL="${2:-1}"
    [ -z "$KEY" ] && exit 1
    redis-cli hincrby "cybra:taxi:metrics:$(date +%Y%m%d)" "$KEY" "$VAL" >/dev/null
    echo "📊 $KEY +$VAL"
    ;;
  today)
    echo "════ metrics $(date +%Y%m%d) ════"
    redis-cli hgetall "cybra:taxi:metrics:$(date +%Y%m%d)" 2>/dev/null | paste - -
    ;;
  week)
    echo "════ metrics last 7 days ════"
    for i in 0 1 2 3 4 5 6; do
      D=$(date -d "-$i days" +%Y%m%d 2>/dev/null || date -v-${i}d +%Y%m%d 2>/dev/null)
      N=$(redis-cli hlen "cybra:taxi:metrics:$D" 2>/dev/null || echo 0)
      echo "  $D: $N metrics"
    done
    ;;
  *)
    echo "════ ${MODULE_LABEL} ════"
    echo "  hint: $0 record <key> [val] | today | week"
    ;;
esac
'''

# ════════ Module map ════════
MODULES = [
    (260, "peer_camera",       "peer",   "show",  PEER_CAMERA),
    (261, "peer_cell",         "peer",   "list",  PEER_CELL),
    (262, "peer_ble",          "peer",   "scan",  PEER_BLE),
    (263, "peer_wifi",         "peer",   "scan",  PEER_WIFI),
    (264, "peer_fusion",       "peer",   "list",  PEER_FUSION),
    (265, "location_fallback", "loc",    "show",  LOCATION_FALLBACK),
    (266, "state_100",         "state",  "check", STATE_100),
    (267, "i18n_loader",       "i18n",   "list",  I18N_LOADER),
    (268, "voice",             "voice",  "listen",VOICE),
    (269, "ai_assistant",      "ai",     "ask",   AI_ASSIST),
    (270, "sos",               "safety", "list",  SOS),
    (271, "live_share",        "share",  "list",  SHARE),
    (272, "app_metrics",       "metrics","today", APP_METRICS),
]

MAIN_HEADER = '''#!/data/data/com.termux/files/usr/bin/bash
# module_{nn}: {name} ({cat}) — ultra
set -u
CYBRA="${{CYBRA:-$HOME/CYBRA}}"; cd "$CYBRA" 2>/dev/null || exit 1
ACTION="${{1:-{default}}}"; shift $(( $# > 0 ? 1 : 0 ))
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
    print("═══ ULTRA DEPLOY (260-272) ═══")
    ts = time.strftime("%FT%TZ")
    created = 0
    for n, name, cat, default, body in MODULES:
        d = find_or_create(n, name)
        main_sh = d / "main.sh"
        content = MAIN_HEADER.format(nn=f"{n:03d}", name=name, cat=cat, default=default) + body
        main_sh.write_text(content)
        os.chmod(main_sh, 0o755)
        if subprocess.run(["bash","-n",str(main_sh)],capture_output=True).returncode == 0:
            created += 1
        else:
            print(f"  ❌ {n}: syntax error")

        ctrl = CTRL / f"ultra_module_{n:03d}.ctrl.sh"
        ctrl.write_text(f'''#!/data/data/com.termux/files/usr/bin/bash
set -u
M="$1"; shift
[ -f "$M" ] || {{ echo "missing"; exit 2; }}
[ $# -gt 0 ] && A=("$@") || A=("list")
bash "$M" "${{A[@]}}" </dev/null 2>&1
exit $?
''')
        os.chmod(ctrl, 0o755)

    print(f"✅ modules: {created}/{len(MODULES)}")
    spec = {n: {"name": name, "category": cat, "default": default} for n, name, cat, default, _ in MODULES}
    SPEC.write_text(json.dumps({"version": "1.0", "generated": ts, "modules": spec}, indent=2, ensure_ascii=False))
    print(f"✅ spec: {SPEC}")
    print(f"✅ i18n: {len(STRINGS)} langs")

    print("\n── TEST ──")
    tests = [
        (266, ["check"]),
        (265, ["mark", "50.45", "30.52"]),
        (267, ["list"]),
        (267, ["set", "uk"]),
        (267, ["get", "welcome"]),
        (260, ["make-qr", "R-TEST"]),
        (261, ["scan"]),
        (272, ["today"]),
    ]
    for n, args in tests:
        d = next((p for p in MODS.glob(f"module_{n}_*") if p.is_dir()), None)
        if not d: continue
        r = subprocess.run(["bash",str(d/"main.sh")] + args, capture_output=True, text=True, timeout=15, input="")
        mark = "✅" if r.returncode == 0 and r.stdout.strip() else "⚠️"
        print(f"  {mark} [{n}] {' '.join(args)}: {r.stdout.splitlines()[0][:80] if r.stdout.strip() else 'empty'}")

if __name__ == "__main__":
    main()
