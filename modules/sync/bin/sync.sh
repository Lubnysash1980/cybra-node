#!/data/data/com.termux/files/usr/bin/bash
set -u
D="$HOME/.cybra-sync"; mkdir -p "$D" "$HOME/CYBRA/logs" "$HOME/CYBRA/.cache"
LOG="$HOME/CYBRA/logs/sync.log"; CONF="$D/config.json"; TOKEN_FILE="$D/token"
PIDFILE="$HOME/CYBRA/.cache/sync.pid"; PORT=8765; INTERVAL=60

[ -f "$CONF" ] || cat > "$CONF" <<'JSON'
{
  "role": null, "peer": null,
  "channels": {"wifi": false, "sd": false, "usb": false, "bt": false, "github": false},
  "paths": {"sd": "", "usb": "", "bt": "", "github_repo": ""},
  "encrypt": false, "auto_dump": false
}
JSON

cfg(){ jq -r "$1" "$CONF" 2>/dev/null; }
setcfg(){ jq "$@" "$CONF" > "$CONF.t" && mv "$CONF.t" "$CONF"; }
log(){ echo "[$(date '+%F %T')] $*" >> "$LOG"; }

preflight(){
  local miss=""
  for p in jq curl python3 rsync tar openssl ssh sshd ssh-keygen git; do
    command -v "$p" >/dev/null || miss="$miss $p"
  done
  [ -n "$miss" ] && { echo "Встанови: pkg install -y openssh rsync jq python curl openssl git"; return 1; }
  [ -f "$HOME/.ssh/id_ed25519" ] || ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" >/dev/null 2>&1
  pgrep -f sshd >/dev/null || sshd 2>/dev/null
  return 0
}

get_ip(){ local i ip; for i in wlan0 wlan1 eth0; do ip=$(ip -4 addr show "$i" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1); [ -n "$ip" ] && { echo "$ip"; return; }; done; }

derive_key(){ echo -n "$1" | sha256sum | head -c 64; }
enc(){ openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -pass "pass:$(derive_key "$TOKEN")"; }

start_server(){
  local ip; ip=$(get_ip); [ -z "$ip" ] && return 1
  [ -z "$TOKEN" ] && return 1
  local my_user; my_user=$(whoami)
  local my_pub; my_pub=$(cat "$HOME/.ssh/id_ed25519.pub")
  cat > "$D/srv.py" <<PY
import http.server, json, os, urllib.parse
TOKEN="$TOKEN"; PUB='''$my_pub'''; AUTH="$HOME/.ssh/authorized_keys"; USER="$my_user"; IP="$ip"
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self,*a): pass
    def do_GET(self):
        if self.path.startswith('/p?t='):
            if urllib.parse.unquote(self.path.split('=',1)[1])==TOKEN:
                self.send_response(200); self.end_headers()
                self.wfile.write(json.dumps({"ok":True,"pub":PUB,"user":USER,"ip":IP}).encode())
            else: self.send_response(403); self.end_headers()
        elif self.path.startswith('/key?k='):
            k=urllib.parse.unquote(self.path.split('=',1)[1])
            os.makedirs(os.path.dirname(AUTH),exist_ok=True)
            L=open(AUTH).read().splitlines() if os.path.exists(AUTH) else []
            if k not in L: open(AUTH,"a").write(k+"\n"); os.chmod(AUTH,0o600)
            self.send_response(200); self.end_headers(); self.wfile.write(b'ok')
        else: self.send_response(404); self.end_headers()
http.server.HTTPServer(('0.0.0.0',$PORT),H).serve_forever()
PY
  pgrep -f "$D/srv.py" >/dev/null || (python3 "$D/srv.py" >/dev/null 2>&1 &)
  sleep 1
}

scan_peer(){
  local ip; ip=$(get_ip); [ -z "$ip" ] && return 1
  local prefix; prefix=$(echo "$ip" | cut -d. -f1-3)
  local ep; ep=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$TOKEN")
  local found="$D/.hit"; rm -f "$found"
  for i in $(seq 1 254); do
    local hip="$prefix.$i"; [ "$hip" = "$ip" ] && continue
    ( r=$(curl -sf -m 1 "http://$hip:$PORT/p?t=$ep" 2>/dev/null)
      echo "$r" | jq -e '.ok==true' >/dev/null 2>&1 && echo "$hip" > "$found" ) &
  done
  wait
  [ -f "$found" ] && { cat "$found"; rm -f "$found"; return 0; }
  return 1
}

EXCL="--exclude=.cache/*.pid --exclude=.cache/*.lock --exclude=.git/ --exclude=.backup/ --exclude=*.tmp"

sync_wifi(){
  [ "$(cfg '.channels.wifi')" = "true" ] || return 0
  local pip puser; pip=$(cfg '(.peer // {}).ip // ""'); puser=$(cfg '(.peer // {}).user // ""')
  [ -z "$pip" ] || [ -z "$puser" ] && return 0
  rsync -azu $EXCL -e "ssh -p 8022 -o BatchMode=yes -o StrictHostKeyChecking=accept-new" \
    "$HOME/CYBRA/" "$puser@$pip:CYBRA/" 2>/dev/null && log "wifi → $pip"
}

sync_local(){
  local kind="$1" path="$2"
  [ -z "$path" ] || [ "$path" = "null" ] && return 0
  [ -d "$path" ] || mkdir -p "$path" 2>/dev/null || { log "$kind: no $path"; return 0; }
  local ts; ts=$(date +%Y%m%d_%H%M%S)
  local tmp="$HOME/.cache/sync-$kind-$ts.tgz"
  tar czf "$tmp" -C "$HOME" CYBRA/ 2>/dev/null || return 0
  if [ "$(cfg '.encrypt')" = "true" ]; then
    enc < "$tmp" > "$path/cybra-$kind-$ts.tgz.enc" && rm -f "$tmp"
  else
    mv "$tmp" "$path/cybra-$kind-$ts.tgz"
  fi
  log "$kind → $path"
  ls -1t "$path"/cybra-$kind-* 2>/dev/null | tail -n +4 | xargs -r rm -f
}

sync_bt(){
  [ "$(cfg '.channels.bt')" = "true" ] || return 0
  local bp; bp=$(cfg '(.paths // {}).bt // ""'); [ -z "$bp" ] && return 0
  rsync -azu $EXCL -e "ssh -p 8022 -o BatchMode=yes -o StrictHostKeyChecking=accept-new" \
    "$HOME/CYBRA/" "$bp:CYBRA/" 2>/dev/null && log "bt → $bp"
}

sync_github(){
  [ "$(cfg '.channels.github')" = "true" ] || return 0
  [ -d "$HOME/CYBRA/.git" ] || { log "github: no git"; return 0; }
  cd "$HOME/CYBRA" || return 0
  git add -A 2>/dev/null
  git diff --cached --quiet || git commit -m "sync: $(date '+%F %T')" 2>/dev/null
  git push 2>/dev/null && log "github push"
  git pull 2>/dev/null && log "github pull"
}

stake_dump(){
  [ -x "$HOME/CYBRA/bin/cybra_dump.sh" ] && "$HOME/CYBRA/bin/cybra_dump.sh" 2>/dev/null
  [ -x "$HOME/CYBRA/bin/cybra_dump_components.sh" ] && "$HOME/CYBRA/bin/cybra_dump_components.sh" 2>/dev/null
  log "stake dump created"
}

sync_now(){
  [ "$(cfg '.auto_dump')" = "true" ] && stake_dump
  sync_wifi; sync_bt
  sync_local sd "$(cfg '(.paths // {}).sd // ""')"
  sync_local usb "$(cfg '(.paths // {}).usb // ""')"
  sync_github
}

daemon(){
  [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null && return 0
  echo $$ > "$PIDFILE"; trap 'rm -f "$PIDFILE"' EXIT
  log "daemon start pid=$$"
  TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null || echo "")
  [ -n "$TOKEN" ] && start_server
  while true; do sync_now; sleep "$INTERVAL"; done
}

start_daemon(){
  [ -z "$TOKEN" ] && { echo "спершу токен (меню 1)"; return 1; }
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then echo "вже працює pid=$(cat "$PIDFILE")"; return 0; fi
  setsid nohup "$0" daemon >/dev/null 2>&1 < /dev/null &
  sleep 2
  [ -f "$PIDFILE" ] && echo "✅ daemon pid=$(cat "$PIDFILE")" || echo "❌ failed"
}

stop_daemon(){
  [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null
  rm -f "$PIDFILE"; pkill -f "$D/srv.py" 2>/dev/null
  echo "⏹ зупинено"
}

ask_token(){
  if [ -n "$TOKEN" ]; then echo "Токен вже є: $TOKEN"; return 0; fi
  echo "  [g] Згенерувати токен (цей = пристрій 1)"
  echo "  [v] Ввести токен з іншого (цей = пристрій 2)"
  printf "  Вибір: "; read -r c
  case "$c" in
    g|G) TOKEN=$(openssl rand -hex 4 | tr 'a-f' 'A-F'); echo "$TOKEN" > "$TOKEN_FILE"; chmod 600 "$TOKEN_FILE"; setcfg '.role="host"'
         echo "✅ Токен: $TOKEN"; echo "   Запиши і введи на іншому пристрої" ;;
    v|V) printf "  Токен: "; read -r TOKEN
         [ -z "$TOKEN" ] && return
         echo "$TOKEN" > "$TOKEN_FILE"; chmod 600 "$TOKEN_FILE"; setcfg '.role="peer"'
         echo "✅ Токен прийнято: $TOKEN" ;;
  esac
}

toggle_channel(){
  local ch="$1"; local cur; cur=$(cfg ".channels.$ch")
  if [ "$cur" = "true" ]; then setcfg ".channels.$ch=false"; echo "$ch OFF"; return; fi
  case "$ch" in
    wifi)
      [ -z "$(get_ip)" ] && { echo "❌ WiFi нема"; return; }
      [ -z "$TOKEN" ] && { echo "❌ спершу токен"; return; }
      echo "🔍 шукаю peer..."; start_server
      local pip; pip=$(scan_peer)
      [ -z "$pip" ] && { echo "❌ peer не знайдено"; return; }
      local resp; resp=$(curl -sf "http://$pip:$PORT/p?t=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$TOKEN")")
      local pu pp; pu=$(echo "$resp"|jq -r .user); pp=$(echo "$resp"|jq -r .pub)
      touch "$HOME/.ssh/authorized_keys"; chmod 600 "$HOME/.ssh/authorized_keys"
      grep -qxF "$pp" "$HOME/.ssh/authorized_keys" || echo "$pp" >> "$HOME/.ssh/authorized_keys"
      local my_pub; my_pub=$(cat "$HOME/.ssh/id_ed25519.pub")
      local epk; epk=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$my_pub")
      curl -sf "http://$pip:$PORT/key?k=$epk" >/dev/null
      setcfg --arg ip "$pip" --arg u "$pu" '.peer={ip:$ip,user:$u} | .channels.wifi=true'
      echo "✅ WiFi ON → $pu@$pip" ;;
    sd) local p; p=$(cfg '(.paths // {}).sd // ""'); [ -z "$p" ] && { printf "  SD шлях: "; read -r p; }
        [ -n "$p" ] && setcfg --arg p "$p" '.channels.sd=true | .paths.sd=$p' && echo "✅ SD ON → $p" ;;
    usb) local p; p=$(cfg '(.paths // {}).usb // ""'); [ -z "$p" ] && { printf "  USB шлях: "; read -r p; }
         [ -n "$p" ] && setcfg --arg p "$p" '.channels.usb=true | .paths.usb=$p' && echo "✅ USB ON → $p" ;;
    bt) local p; p=$(cfg '(.paths // {}).bt // ""'); [ -z "$p" ] && { printf "  BT peer user@ip:8022: "; read -r p; }
        [ -n "$p" ] && setcfg --arg p "$p" '.channels.bt=true | .paths.bt=$p' && echo "✅ BT ON → $p" ;;
    github) [ -d "$HOME/CYBRA/.git" ] || { echo "❌ no git repo"; return; }
            setcfg '.channels.github=true'; echo "✅ GitHub ON" ;;
  esac
}

status(){
  local d; if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then d="RUNNING pid=$(cat "$PIDFILE")"; else d="STOPPED"; fi
  echo "════════════════════════════════════════"
  echo "  Токен:   ${TOKEN:-не задано}"
  echo "  IP:      $(get_ip || echo '—')"
  echo "  Peer:    $(cfg '(.peer // {}).user // ""')@$(cfg '(.peer // {}).ip // ""')"
  echo "  Daemon:  $d"
  echo "  WiFi:    $(cfg '.channels.wifi')"
  echo "  SD:      $(cfg '.channels.sd') $(cfg '(.paths // {}).sd // ""')"
  echo "  USB:     $(cfg '.channels.usb') $(cfg '(.paths // {}).usb // ""')"
  echo "  BT:      $(cfg '.channels.bt') $(cfg '(.paths // {}).bt // ""')"
  echo "  GitHub:  $(cfg '.channels.github')"
  echo "  Encrypt: $(cfg '.encrypt')"
  echo "  AutoDump:$(cfg '.auto_dump')"
  echo "════════════════════════════════════════"
}

do_reset(){
  stop_daemon; rm -f "$CONF" "$TOKEN_FILE"
  cat > "$CONF" <<'JSON'
{"role":null,"peer":null,"channels":{"wifi":false,"sd":false,"usb":false,"bt":false,"github":false},"paths":{"sd":"","usb":"","bt":"","github_repo":""},"encrypt":false,"auto_dump":false}
JSON
  TOKEN=""; echo "Reset"
}

install_as_module(){
  local M="$HOME/CYBRA/modules/sync"
  mkdir -p "$M/bin" "$M/state"
  cp "$0" "$M/bin/sync.sh"; chmod +x "$M/bin/sync.sh"
  cat > "$M/manifest.json" <<'JSON'
{"id":"sync","name":"Sync","version":"1.0.0","license":"MIT",
 "description":"Multi-channel sync: WiFi, SD, USB, BT, GitHub.",
 "depends":["stakeawtodump"],"state_dir":"state",
 "entrypoints":{"ctl":"bin/sync.sh"}}
JSON
  echo "✅ модуль: modules/sync/"
  echo "  pm2 start $M/bin/sync.sh --name cybra-sync --interpreter bash -- daemon"
}

menu(){
  while true; do
    clear; status; echo ""
    echo "  1) Токен (створити/ввести)"
    echo "  2) WiFi:    $([ "$(cfg '.channels.wifi')" = "true" ] && echo ON || echo OFF)"
    echo "  3) SD:      $([ "$(cfg '.channels.sd')" = "true" ] && echo ON || echo OFF)"
    echo "  4) USB:     $([ "$(cfg '.channels.usb')" = "true" ] && echo ON || echo OFF)"
    echo "  5) BT:      $([ "$(cfg '.channels.bt')" = "true" ] && echo ON || echo OFF)"
    echo "  6) GitHub:  $([ "$(cfg '.channels.github')" = "true" ] && echo ON || echo OFF)"
    echo "  7) Encrypt: $([ "$(cfg '.encrypt')" = "true" ] && echo ON || echo OFF)"
    echo "  8) AutoDump:$([ "$(cfg '.auto_dump')" = "true" ] && echo ON || echo OFF)"
    echo "  9) Stake dump зараз"
    echo " 10) Sync now"
    echo " 11) Daemon start/stop"
    echo " 12) Install as module + pm2"
    echo " 13) Reset"
    echo "  0) Exit"
    printf "  Вибір: "; read -r c
    case "$c" in
      1) ask_token ;;
      2) toggle_channel wifi ;;
      3) toggle_channel sd ;;
      4) toggle_channel usb ;;
      5) toggle_channel bt ;;
      6) toggle_channel github ;;
      7) [ "$(cfg '.encrypt')" = "true" ] && setcfg '.encrypt=false' || setcfg '.encrypt=true'; echo "Encrypt toggle" ;;
      8) [ "$(cfg '.auto_dump')" = "true" ] && setcfg '.auto_dump=false' || setcfg '.auto_dump=true'; echo "AutoDump toggle" ;;
      9) stake_dump ;;
      10) sync_now; echo done ;;
      11) if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then stop_daemon; else start_daemon; fi ;;
      12) install_as_module ;;
      13) do_reset ;;
      0) exit 0 ;;
    esac
    printf "\nEnter..."; read -r _
  done
}

preflight || exit 1
TOKEN=$(cat "$TOKEN_FILE" 2>/dev/null || echo "")

case "${1:-menu}" in
  daemon) daemon ;;
  start) start_daemon ;;
  stop) stop_daemon ;;
  sync) sync_now; echo done ;;
  dump) stake_dump ;;
  status) status ;;
  install) install_as_module ;;
  reset) do_reset ;;
  *) menu ;;
esac
