#!/data/data/com.termux/files/usr/bin/bash
MC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONF="$MC_ROOT/state/chains.env"
[ -f "$CONF" ] && source "$CONF"

mc_list() {
    printf '%-10s %-20s %-8s %s\n' "KEY" "NAME" "CHAIN" "EXPLORER"
    printf -- '----\n'
    for c in BSC ETH POLYGON ARBITRUM; do
        eval "name=\$CHAIN_${c}_NAME"
        eval "id=\$CHAIN_${c}_ID"
        eval "exp=\$CHAIN_${c}_EXPLORER"
        printf '%-10s %-20s %-8s %s\n' "$c" "$name" "$id" "$exp"
    done
}

mc_get_id() {
    local key="$1"
    eval "echo \$CHAIN_${key}_ID"
}

mc_get_rpc() {
    local key="$1"
    eval "echo \$CHAIN_${key}_RPC"
}

mc_get_explorer() {
    local key="$1"
    eval "echo \$CHAIN_${key}_EXPLORER"
}

mc_tx_link() {
    local key="$1" tx="$2"
    local exp="$(mc_get_explorer "$key")"
    echo "$exp/tx/$tx"
}

mc_addr_link() {
    local key="$1" addr="$2"
    local exp="$(mc_get_explorer "$key")"
    echo "$exp/address/$addr"
}

mc_default() {
    echo "${DEFAULT_CHAIN:-BSC}"
}

mc_set_default() {
    local key="$1"
    sed -i "s|^DEFAULT_CHAIN=.*|DEFAULT_CHAIN=$key|" "$CONF"
    echo "OK"
}
