#!/data/data/com.termux/files/usr/bin/bash
# cybra_pair.sh v1.0 — pairing + continuous push sync
set -u
PAIR_DIR="$HOME/.cybra-sync"
PAIR_FILE="$PAIR_DIR/pairing.json"
LOG="$HOME/CYBRA/logs/sync.log"
PIDFILE="$HOME/CYBRA/.cache/sync-daemon.pid"
PORT=8765
INTERVAL=30
mkdir -p "$PAIR_DIR" "$(dirname "$LOG")" "$HOME/CYBRA/.cache" "$HOME/.ssh"
chmod 700 "$HOME/.ssh" 2>/dev/null

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
die(){ log "❌ $*"; exit 1; }
ok(){  log "✅ $*"; }
info(){ log "── $*"; }
have(){ command -v "$1" >/dev/null 2>&1; }

preflight(){
    local miss=""
    for p in jq curl python3 ssh rsync sshd ssh-keygen; do
        have "$p" || miss="$miss $p"
    done
    [ -n "$miss" ] && die "missing:$miss — pkg install -y openssh rsync jq python curl"
    [ -f "$HOME/.ssh/id_ed25519" ] || ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" >/dev/null 2>&1
    pgrep -f sshd >/dev/null || { sshd; sleep 1; }
    pgrep -f sshd >/dev/null || die "sshd не запущено — виконай 'sshd' вручну"
}

get_ip(){
    local iface ip
    for iface in wlan0 wlan1 eth0; do
        ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
        [ -n "$ip" ] && { echo "$ip"; return; }
    done
    ip -4 addr show 2>/dev/null | grep -oP 'inet \K[\d.]+' | grep -v '^127\.' | head -1
}

is_lan_ip(){
    case "$1" in 192.168.*|10.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*) return 0 ;; esac
    return 1
}

gen_pin(){ printf '%06d\n' $(( (RANDOM * 32768 + RANDOM) % 1000000 )); }
pair_exists(){ [ -f "$PAIR_FILE" ] && jq -e '.peer.host // .peer.ip' "$PAIR_FILE" >/dev/null 2>&1; }

# ═══════════════════════════════════════════════════════
# HOST: init
# ═══════════════════════════════════════════════════════
do_init(){
    preflight
    local my_ip; my_ip=$(get_ip)
    [ -z "$my_ip" ] && die "немає IP — WiFi увімкнено? VPN вимкнено?"
    is_lan_ip "$my_ip" || die "IP $my_ip не в LAN (мобільний інтернет/VPN) — потрібен спільний WiFi"

    local pin; pin=$(gen_pin)
    local user; user=$(whoami)
    local pubkey; pubkey=$(cat "$HOME/.ssh/id_ed25519.pub")

    cat > "$PAIR_FILE" << JSON
{
  "role": "host", "pin": "$pin", "ts": "$(date -Iseconds)",
  "me": {"user": "$user", "ip": "$my_ip", "port": $PORT, "pubkey": "$pubkey"},
  "peer": null
}
JSON
    chmod 600 "$PAIR_FILE"

    local serve="$PAIR_DIR/pair-server.py"
    cat > "$serve" << 'PY'
import http.server, json, os, sys
from urllib.parse import urlparse, parse_qs
PAIR_FILE = os.path.expanduser("~/.cybra-sync/pairing.json")
AUTH_KEYS = os.path.expanduser("~/.ssh/authorized_keys")
SELF_SCRIPT = os.path.expanduser("~/CYBRA/bin/cybra_pair.sh")

def load():
    return json.load(open(PAIR_FILE))
def save(d):
    with open(PAIR_FILE, "w") as f: json.dump(d, f, indent=2)
def add_key(pk):
    os.makedirs(os.path.dirname(AUTH_KEYS), exist_ok=True)
    lines = []
    if os.path.exists(AUTH_KEYS):
        lines = open(AUTH_KEYS).read().splitlines()
    if pk.strip() not in lines:
        with open(AUTH_KEYS, "a") as f: f.write(pk.strip() + "\n")
        try: os.chmod(AUTH_KEYS, 0o600)
        except: pass

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        u = urlparse(self.path)
        if u.path == '/.cybra-pair':
            q = parse_qs(u.query)
            want = q.get('pin', [''])[0]
            d = load()
            if want == d.get('pin'):
                me = d['me']
                r = {"ok": True, "user": me["user"], "ip": me["ip"], "port": me["port"], "pubkey": me["pubkey"]}
                self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers()
                self.wfile.write(json.dumps(r).encode())
            else:
                self.send_response(403); self.end_headers()
        elif u.path == '/cybra_pair.sh':
            if os.path.exists(SELF_SCRIPT):
                data = open(SELF_SCRIPT, 'rb').read()
                self.send_response(200); self.send_header('Content-Type','text/plain'); self.end_headers()
                self.wfile.write(data)
            else:
                self.send_response(404); self.end_headers()
        else:
            self.send_response(404); self.end_headers()
    def do_POST(self):
        if self.path == '/.cybra-register':
            try:
                n = int(self.headers.get('Content-Length', 0))
                data = json.loads(self.rfile.read(n).decode())
                d = load()
                if data.get('pin') != d.get('pin'):
                    self.send_response(403); self.end_headers(); return
                add_key(data['pubkey'])
                d['peer'] = {"user": data["user"], "ip": data["ip"], "port": 8022,
                             "pubkey": data["pubkey"], "paired_ts": data.get("ts")}
                save(d)
                self.send_response(200); self.send_header('Content-Type','application/json'); self.end_headers()
                self.wfile.write(b'{"ok":true}')
            except Exception as e:
                self.send_response(500); self.end_headers()
        else:
            self.send_response(404); self.end_headers()

http.server.HTTPServer(('0.0.0.0', int(sys.argv[1]) if len(sys.argv)>1 else 8765), H).serve_forever()
PY

    python3 "$serve" "$PORT" &
    local srv=$!
    trap 'kill '"$srv"' 2>/dev/null' EXIT INT TERM

    sleep 1
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  🔑 PAIRING — HOST"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "   PIN:    $pin"
    echo "   IP:     $my_ip"
    echo "   User:   $user"
    echo ""
    echo "  ▶ На іншому пристрої:"
    echo ""
    echo "    # Спершу встанови пакети + запусти sshd:"
    echo "    pkg install -y openssh rsync jq python curl && sshd"
    echo ""
    echo "    # Потім скачай скрипт і запусти:"
    echo "    curl -s http://$my_ip:$PORT/cybra_pair.sh -o ~/cybra_pair.sh"
    echo "    chmod +x ~/cybra_pair.sh"
    echo "    ~/cybra_pair.sh join $pin"
    echo ""
    echo "  Чекаю на приєднання... (Ctrl-C — вихід)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    local waited=0
    while [ "$(jq -r '.peer // "null"' "$PAIR_FILE" 2>/dev/null)" = "null" ]; do
        sleep 2
        waited=$((waited+2))
        [ $((waited % 30)) -eq 0 ] && info "waited ${waited}s"
        kill -0 "$srv" 2>/dev/null || die "server died"
    done

    ok "peer joined!"
    local peer_ip peer_user
    peer_ip=$(jq -r '.peer.ip' "$PAIR_FILE")
    peer_user=$(jq -r '.peer.user' "$PAIR_FILE")
    info "test ssh $peer_user@$peer_ip"
    local tries=0
    while [ $tries -lt 15 ]; do
        tries=$((tries+1))
        ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=3 -o BatchMode=yes -p 8022 "$peer_user@$peer_ip" "echo ok" 2>/dev/null | grep -q ok && { ok "ssh ok"; break; }
        warn "ssh try $tries/15..."; sleep 2
    done

    info "starting sync daemon"
    daemon_start
    ok "════ PAIRING COMPLETE ════"
    echo ""
    echo "  peer: $peer_user@$peer_ip"
    echo "  logs: $LOG"
}

# ═══════════════════════════════════════════════════════
# PEER: join
# ═══════════════════════════════════════════════════════
scan_for_pin(){
    local pin="$1" timeout=30
    local my_ip; my_ip=$(get_ip)
    [ -z "$my_ip" ] && die "немає IP"
    is_lan_ip "$my_ip" || die "IP $my_ip не в LAN"
    local prefix; prefix=$(echo "$my_ip" | awk -F. '{print $1"."$2"."$3}')
    info "scan $prefix.1-254:$PORT"
    local found; found=$(mktemp)
    local start; start=$(date +%s)
    while [ $(( $(date +%s) - start )) -lt "$timeout" ] && [ ! -s "$found" ]; do
        for b in 1 32 64 96 128 160 192 224; do
            [ -s "$found" ] && break
            for i in $(seq "$b" $((b+31))); do
                (
                    local ip="$prefix.$i"
                    [ "$ip" = "$my_ip" ] && exit 0
                    local r; r=$(curl -sf -m 1 "http://$ip:$PORT/.cybra-pair?pin=$pin" 2>/dev/null)
                    echo "$r" | jq -e '.ok==true' >/dev/null 2>&1 && echo "$ip" > "$found"
                ) &
            done
            wait 2>/dev/null
        done
    done
    if [ -s "$found" ]; then cat "$found"; rm -f "$found"; return 0; fi
    rm -f "$found"; return 1
}

do_join(){
    local pin="${1:-}"
    [ -z "$pin" ] && { printf "  Введи 6-значний PIN: "; read -r pin; }
    [ ${#pin} -ne 6 ] && die "PIN має бути 6 цифр"

    preflight

    info "auto-discovery"
    local host_ip; host_ip=$(scan_for_pin "$pin") || die "не знайдено host з PIN $pin — впевнись що обидва в одному WiFi"
    ok "host: $host_ip:$PORT"

    info "handshake"
    local resp
    resp=$(curl -sf -m 5 "http://$host_ip:$PORT/.cybra-pair?pin=$pin") || die "handshake failed"
    local host_user host_pubkey
    host_user=$(echo "$resp" | jq -r '.user')
    host_pubkey=$(echo "$resp" | jq -r '.pubkey')
    ok "host user: $host_user"

    info "add host pubkey → our authorized_keys"
    mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"; chmod 600 "$HOME/.ssh/authorized_keys"
    grep -qxF "$host_pubkey" "$HOME/.ssh/authorized_keys" || echo "$host_pubkey" >> "$HOME/.ssh/authorized_keys"

    local my_user; my_user=$(whoami)
    local my_ip; my_ip=$(get_ip)
    local my_pubkey; my_pubkey=$(cat "$HOME/.ssh/id_ed25519.pub")

    info "register with host"
    curl -sf -m 5 -X POST "http://$host_ip:$PORT/.cybra-register" \
        -H 'Content-Type: application/json' \
        -d "$(jq -n --arg p "$pin" --arg u "$my_user" --arg ip "$my_ip" --arg pk "$my_pubkey" --arg ts "$(date -Iseconds)" \
              '{pin:$p, user:$u, ip:$ip, pubkey:$pk, ts:$ts}')" >/dev/null || die "register failed"

    cat > "$PAIR_FILE" << JSON
{
  "role": "peer", "ts": "$(date -Iseconds)",
  "me": {"user": "$my_user", "ip": "$my_ip", "port": 8022, "pubkey": "$my_pubkey"},
  "peer": {"user": "$host_user", "ip": "$host_ip", "port": 8022, "paired_ts": "$(date -Iseconds)"}
}
JSON
    chmod 600 "$PAIR_FILE"

    info "test ssh"
    local tries=0
    while [ $tries -lt 15 ]; do
        tries=$((tries+1))
        ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=3 -o BatchMode=yes -p 8022 "$host_user@$host_ip" "echo ok" 2>/dev/null | grep -q ok && { ok "ssh ok"; break; }
        warn "try $tries/15"; sleep 2
    done

    info "starting sync daemon"
    daemon_start
    ok "════ JOINED ════"
}

# ═══════════════════════════════════════════════════════
# SYNC (rsync push)
# ═══════════════════════════════════════════════════════
rsync_push(){
    pair_exists || return 1
    local u h p
    u=$(jq -r '.peer.user' "$PAIR_FILE")
    h=$(jq -r '.peer.ip' "$PAIR_FILE")
    p=$(jq -r '.peer.port // 8022' "$PAIR_FILE")

    local excl=( --exclude='.cache/*.pid' --exclude='.cache/*.lock' --exclude='.cache/*.stamp'
                 --exclude='.git/' --exclude='.backup/' --exclude='*.tmp' --exclude='node_modules/' )

    # 1) CYBRA code + dumps + state + logs
    rsync -azu --itemize-changes "${excl[@]}" \
        -e "ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o BatchMode=yes -p $p" \
        "$HOME/CYBRA/" "$u@$h:CYBRA/" 2>&1

    # 2) golden (поза CYBRA, окремо)
    if [ -d "$HOME/.cybra-golden" ]; then
        rsync -azu "${excl[@]}" -e "ssh -p $p -o BatchMode=yes" \
            "$HOME/.cybra-golden/" "$u@$h:.cybra-golden/" 2>/dev/null | tail -1
    fi
}

# ═══════════════════════════════════════════════════════
# DAEMON
# ═══════════════════════════════════════════════════════
daemon_run(){
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null && die "already running"
    echo $$ > "$PIDFILE"; trap 'rm -f "$PIDFILE"' EXIT
    log "═══ SYNC DAEMON START ═══ pid=$$ interval=${INTERVAL}s"
    while true; do
        if ! pair_exists; then log "no pair"; sleep "$INTERVAL"; continue; fi
        local h u
        u=$(jq -r '.peer.user' "$PAIR_FILE"); h=$(jq -r '.peer.ip' "$PAIR_FILE")
        # reachability
        if ! ssh -o ConnectTimeout=3 -o BatchMode=yes -p 8022 "$u@$h" "echo ok" 2>/dev/null | grep -q ok; then
            log "peer $h unreachable — retry in ${INTERVAL}s"
            sleep "$INTERVAL"; continue
        fi
        # sync
        local out; out=$(rsync_push)
        local changes; changes=$(echo "$out" | grep -c '^>f' 2>/dev/null || echo 0)
        local dumps; dumps=$(echo "$out" | grep -c 'dumps/' 2>/dev/null || echo 0)
        if [ "$changes" -gt 0 ]; then
            log "pushed $changes files"$([ "$dumps" -gt 0 ] && echo " (dumps: $dumps)")
        fi
        sleep "$INTERVAL"
    done
}

daemon_start(){
    [ -f "$PAIR_FILE" ] || die "не paired — спочатку init або join"
    setsid nohup "$0" daemon run >/dev/null 2>&1 < /dev/null &
    sleep 2
    [ -f "$PIDFILE" ] && ok "daemon started pid=$(cat "$PIDFILE")" || die "daemon failed"
}
daemon_stop(){
    [ -f "$PIDFILE" ] && { local p; p=$(cat "$PIDFILE"); kill "$p" 2>/dev/null; sleep 1; kill -9 "$p" 2>/dev/null; rm -f "$PIDFILE"; ok "stopped"; } || echo "not running"
}

# ═══════════════════════════════════════════════════════
# STATUS / TEST / RESET / INTERACTIVE
# ═══════════════════════════════════════════════════════
do_status(){
    echo "── pairing ──"
    [ -f "$PAIR_FILE" ] && jq . "$PAIR_FILE" || echo "  (не paired)"
    echo ""
    echo "── daemon ──"
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
        echo "  RUNNING pid=$(cat "$PIDFILE")"
        echo ""; echo "── last 5 log ──"; tail -5 "$LOG"
    else echo "  STOPPED"; fi
}

do_test(){
    preflight; pair_exists || die "не paired"
    local u h p; u=$(jq -r '.peer.user' "$PAIR_FILE"); h=$(jq -r '.peer.ip' "$PAIR_FILE"); p=$(jq -r '.peer.port // 8022' "$PAIR_FILE")
    info "1. ping $h"; ping -c 2 -W 2 "$h" 2>&1 | tail -2
    info "2. ssh"; ssh -o ConnectTimeout=3 -o BatchMode=yes -p "$p" "$u@$h" "echo ok" 2>&1
    info "3. rsync"; ssh -p "$p" "$u@$h" "command -v rsync" 2>&1
    info "4. peer CYBRA"; ssh -p "$p" "$u@$h" "ls -d ~/CYBRA" 2>&1
}

do_reset(){
    info "reset pairing"
    daemon_stop
    [ -f "$PAIR_FILE" ] && { mv "$PAIR_FILE" "$PAIR_FILE.bak.$(date +%s)"; ok "backed up + reset"; }
}

interactive(){
    if pair_exists; then
        echo "Вже paired з $(jq -r '.peer.user' "$PAIR_FILE")@$(jq -r '.peer.ip' "$PAIR_FILE")"
        echo ""
        echo "  $0 status"
        echo "  $0 test"
        echo "  $0 reset      (розірвати пару)"
        echo "  $0 daemon start|stop"
        return 0
    fi
    echo "═══════════════════════════════════════════"
    echo "  🔑 CYBRA PAIRING"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "  [g] Згенерувати PIN (це перший пристрій)"
    echo "  [j] Приєднатись (це другий пристрій)"
    echo "  [q] Вихід"
    echo ""
    printf "  Вибір [g/j/q]: "
    read -r c
    case "$c" in
        g|G) do_init ;;
        j|J) do_join ;;
        *) echo "quit" ;;
    esac
}

case "${1:-}" in
    init) do_init ;;
    join) shift; do_join "$@" ;;
    daemon) shift; case "${1:-}" in
        start) daemon_start ;;
        stop) daemon_stop ;;
        run) daemon_run ;;
        *) echo "usage: daemon {start|stop|run}"; exit 1 ;;
    esac ;;
    status) do_status ;;
    test) do_test ;;
    reset) do_reset ;;
    -h|--help|help) echo "usage: $0 [init|join [PIN]|status|test|reset|daemon start|stop]"; echo "  без аргументів → інтерактивно" ;;
    "") interactive ;;
    *) interactive ;;
esac
