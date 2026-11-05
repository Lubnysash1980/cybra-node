#!/data/data/com.termux/files/usr/bin/bash
# cybra_sync.sh — WiFi sync між Termux через rsync+ssh
set -u
VERSION=1.0
SYNC_DIR="$HOME/.cybra-sync"
PEERS_FILE="$SYNC_DIR/peers.json"
LOG="$HOME/CYBRA/logs/sync.log"
PIDFILE="$HOME/CYBRA/.cache/sync-daemon.pid"
mkdir -p "$SYNC_DIR" "$(dirname "$LOG")" "$HOME/CYBRA/.cache"

EXCLUDE=(
    --exclude='.cache/*.pid'
    --exclude='.cache/*.lock'
    --exclude='.cache/*.stamp'
    --exclude='.git/'
    --exclude='.git'
    --exclude='.backup/'
    --exclude='*.tmp'
    --exclude='*.swp'
    --exclude='node_modules/'
    --exclude='.cybra-sync/'
)

log(){ echo "[$(date '+%F %T')] $*" | tee -a "$LOG"; }
die(){ log "❌ $*"; exit 1; }
ok(){  log "✅ $*"; }
info(){ log "── $*"; }
warn(){ log "⚠  $*"; }

init_peers(){ [ -f "$PEERS_FILE" ] || echo '{"peers":{},"primary":null}' > "$PEERS_FILE"; }
ssh_opt(){ echo "-o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 -o BatchMode=yes"; }

get_local_ip(){
    local iface ip
    for iface in wlan0 wlan1 eth0; do
        ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
        [ -n "$ip" ] && { echo "$ip"; return; }
    done
    ip -4 addr show 2>/dev/null | grep -oP 'inet \K[\d.]+' | grep -v '^127\.' | head -1
}

peer_exists(){ init_peers; jq -e --arg n "$1" '.peers[$n]' "$PEERS_FILE" >/dev/null 2>&1; }
get_peer(){ jq -r --arg n "$1" '.peers[$n] | "\(.user) \(.host) \(.port)"' "$PEERS_FILE" 2>/dev/null; }

# ─── peer ───
peer_add(){
    local name="" addr="" port="8022"
    while [ $# -gt 0 ]; do
        case "$1" in
            --port) port="$2"; shift 2 ;;
            *) if [ -z "$name" ]; then name="$1"
               elif [ -z "$addr" ]; then addr="$1"; fi
               shift ;;
        esac
    done
    [ -z "$name" ] || [ -z "$addr" ] && die "usage: peer add <name> <user@host> [--port 8022]"
    init_peers
    local user="${addr%%@*}" host="${addr##*@}"
    [ "$user" = "$addr" ] && die "use user@host format (напр. u0_a424@192.168.1.50)"
    [ "$host" = "${host#*:}" ] && { : ; } || { port="${host##*:}"; host="${host%%:*}"; }

    info "test ssh $user@$host:$port"
    if ssh $(ssh_opt) -p "$port" "$user@$host" "echo ok" 2>/dev/null | grep -q ok; then
        ok "ssh works"
    else
        warn "ssh failed — run on peer:"
        warn "  pkg install openssh rsync"
        warn "  ssh-keygen -t ed25519 -N ''"
        warn "  # на цьому: ssh-copy-id -p $port $user@$host"
    fi

    jq --arg n "$name" --arg u "$user" --arg h "$host" --argjson p "$port" \
       '.peers[$n] = {user:$u, host:$h, port:$p, last_sync:null}' \
       "$PEERS_FILE" > "$PEERS_FILE.t" && mv "$PEERS_FILE.t" "$PEERS_FILE"
    ok "peer '$name' = $user@$host:$port"
}

peer_list(){
    init_peers
    echo "── peers ──"
    jq -r '.peers | to_entries[] | "  \(.key): \(.value.user)@\(.value.host):\(.value.port)  last=\(.value.last_sync // "never")"' "$PEERS_FILE"
    local p; p=$(jq -r '.primary // "none"' "$PEERS_FILE")
    echo "  primary: $p"
}

peer_remove(){
    peer_exists "$1" || die "peer '$1' not found"
    jq --arg n "$1" 'del(.peers[$n])' "$PEERS_FILE" > "$PEERS_FILE.t" && mv "$PEERS_FILE.t" "$PEERS_FILE"
    ok "peer '$1' removed"
}

peer_discover(){
    local timeout="${1:-30}"
    local my_ip; my_ip=$(get_local_ip)
    [ -z "$my_ip" ] && die "no WiFi IP"
    local prefix; prefix=$(echo "$my_ip" | awk -F. '{print $1"."$2"."$3}')
    info "scan $prefix.1-254:8022 (${timeout}s)"
    local found; found=$(mktemp)
    local start; start=$(date +%s)
    while [ $(( $(date +%s) - start )) -lt "$timeout" ] && [ ! -s "$found" ]; do
        for b in 1 32 64 96 128 160 192 224; do
            [ -s "$found" ] && break
            local end=$((b+31))
            for i in $(seq "$b" "$end"); do
                local ip="$prefix.$i"
                [ "$ip" = "$my_ip" ] && continue
                ( timeout 1 bash -c "echo > /dev/tcp/$ip/8022" 2>/dev/null && echo "$ip" >> "$found" ) &
            done
            wait 2>/dev/null
        done
    done
    [ ! -s "$found" ] && { rm -f "$found"; die "no SSH peers found (AP isolation?)"; }
    echo "── candidates ──"
    while read -r ip; do
        local who; who=$(ssh $(ssh_opt) -p 8022 "$(whoami)@$ip" whoami 2>/dev/null || true)
        [ -n "$who" ] && echo "  ✅ $who@$ip:8022 (ready)" || echo "  ⚠  $ip:8022 (auth needed: ssh-copy-id -p 8022 <user>@$ip)"
    done < "$found"
    rm -f "$found"
}

# ─── rsync ───
rsync_push(){
    local p; p=$(get_peer "$1"); [ -z "$p" ] && die "peer '$1' not found"
    local u h pt; u=$(echo "$p"|awk '{print $1}'); h=$(echo "$p"|awk '{print $2}'); pt=$(echo "$p"|awk '{print $3}')
    info "push → $1"
    rsync -avzu --itemize-changes "${EXCLUDE[@]}" -e "ssh $(ssh_opt) -p $pt" \
        "$HOME/CYBRA/" "$u@$h:CYBRA/" 2>&1 | tail -15
    return ${PIPESTATUS[0]}
}

rsync_pull(){
    local p; p=$(get_peer "$1"); [ -z "$p" ] && die "peer '$1' not found"
    local u h pt; u=$(echo "$p"|awk '{print $1}'); h=$(echo "$p"|awk '{print $2}'); pt=$(echo "$p"|awk '{print $3}')
    info "pull ← $1"
    rsync -avzu --itemize-changes "${EXCLUDE[@]}" -e "ssh $(ssh_opt) -p $pt" \
        "$u@$h:CYBRA/" "$HOME/CYBRA/" 2>&1 | tail -15
    return ${PIPESTATUS[0]}
}

update_last_sync(){
    jq --arg n "$1" --arg ts "$(date -Iseconds)" \
       '.peers[$n].last_sync = $ts' "$PEERS_FILE" > "$PEERS_FILE.t" && mv "$PEERS_FILE.t" "$PEERS_FILE"
}

# ─── commands ───
do_push(){ [ -z "$1" ] && die "usage: push <peer>"
    rsync_push "$1" || die "push failed"; update_last_sync "$1"; ok "pushed → $1"; }

do_pull(){ [ -z "$1" ] && die "usage: pull <peer>"
    rsync_pull "$1" || die "pull failed"; ok "pulled ← $1"; }

do_sync(){ [ -z "$1" ] && die "usage: sync <peer>"
    info "═══ SYNC $1 ═══"
    rsync_push "$1" || warn "push failed, continuing"
    rsync_pull "$1" || { warn "pull failed"; return 1; }
    update_last_sync "$1"
    ok "sync $1 complete"; }

do_sync_all(){
    init_peers
    local peers; peers=$(jq -r '.peers | keys[]' "$PEERS_FILE")
    [ -z "$peers" ] && die "no peers"
    for p in $peers; do do_sync "$p"; echo ""; done
}

do_test(){
    local p; p=$(get_peer "$1"); [ -z "$p" ] && die "peer '$1' not found"
    local u h pt; u=$(echo "$p"|awk '{print $1}'); h=$(echo "$p"|awk '{print $2}'); pt=$(echo "$p"|awk '{print $3}')
    info "1. ping $h"; ping -c 2 -W 2 "$h" 2>&1 | tail -2
    info "2. port $pt"; timeout 2 bash -c "echo > /dev/tcp/$h/$pt" 2>/dev/null && ok "open" || warn "closed"
    info "3. ssh $u@$h"; ssh $(ssh_opt) -p "$pt" "$u@$h" "echo auth ok" 2>&1
    info "4. peer rsync"; ssh $(ssh_opt) -p "$pt" "$u@$h" "command -v rsync" 2>&1
    info "5. peer CYBRA"; ssh $(ssh_opt) -p "$pt" "$u@$h" "ls -d ~/CYBRA 2>/dev/null" 2>&1
}

# ─── daemon ───
daemon_run(){
    local interval="${1:-300}" peer="${2:-}"
    [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null && die "already running pid=$(cat "$PIDFILE")"
    echo $$ > "$PIDFILE"
    trap 'rm -f "$PIDFILE"' EXIT
    log "═══ SYNC DAEMON START ═══ pid=$$ interval=${interval}s peer=${peer:-all}"
    while true; do
        if [ -n "$peer" ]; then do_sync "$peer" >/dev/null 2>&1 || warn "sync $peer failed"
        else do_sync_all >/dev/null 2>&1 || warn "sync-all failed"; fi
        sleep "$interval"
    done
}

daemon_start(){
    local interval=300 peer=""
    while [ $# -gt 0 ]; do case "$1" in
        --interval) interval="$2"; shift 2 ;;
        --peer) peer="$2"; shift 2 ;;
        *) shift ;; esac; done
    setsid nohup "$0" daemon run "$interval" "$peer" >/dev/null 2>&1 < /dev/null &
    sleep 2
    [ -f "$PIDFILE" ] && ok "daemon started pid=$(cat "$PIDFILE")" || die "daemon start failed"
}

daemon_stop(){
    [ -f "$PIDFILE" ] && { local p; p=$(cat "$PIDFILE"); kill "$p" 2>/dev/null; sleep 1; kill -9 "$p" 2>/dev/null; rm -f "$PIDFILE"; ok "daemon stopped"; } || echo "not running"
}

do_status(){
    init_peers; peer_list; echo ""; echo "── daemon ──"
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE" 2>/dev/null)" 2>/dev/null; then
        echo "  RUNNING pid=$(cat "$PIDFILE")"; tail -3 "$LOG"
    else echo "  STOPPED"; fi
}

usage(){
    cat <<EOF
cybra_sync.sh v$VERSION — WiFi sync Termux (rsync+ssh)

  peer add <name> <user@host> [--port 8022]   register peer
  peer list                                    show peers
  peer remove <name>                           remove
  peer discover [timeout]                      scan LAN:8022

  push <peer>       local → peer
  pull <peer>       peer → local
  sync <peer>       bidirectional (newer wins)
  sync-all          all peers

  daemon start [--interval 300] [--peer NAME]
  daemon stop
  daemon status

  test <peer>       connectivity check
  status            overview

  Setup (on BOTH devices):
    pkg install openssh rsync jq
    ssh-keygen -t ed25519 -N ''
    passwd
    sshd
    # exchange keys:
    ssh-copy-id -p 8022 <other-user>@<other-ip>

  Excluded: .cache/*.pid, *.lock, .git/, .backup/, *.tmp
EOF
}

case "${1:-}" in
    peer) shift; case "${1:-}" in
        add) shift; peer_add "$@" ;;
        list|ls) peer_list ;;
        remove|rm) shift; peer_remove "$@" ;;
        discover) shift; peer_discover "$@" ;;
        *) echo "usage: peer {add|list|remove|discover}"; exit 1 ;;
    esac ;;
    push) shift; do_push "$@" ;;
    pull) shift; do_pull "$@" ;;
    sync) shift; do_sync "$@" ;;
    sync-all) do_sync_all ;;
    test) shift; do_test "$@" ;;
    status) do_status ;;
    daemon) shift; case "${1:-}" in
        start) shift; daemon_start "$@" ;;
        stop) daemon_stop ;;
        run) shift; daemon_run "$@" ;;
        status) do_status ;;
        *) echo "usage: daemon {start|stop|run|status}"; exit 1 ;;
    esac ;;
    -h|--help|help|"") usage ;;
    *) usage; exit 1 ;;
esac
