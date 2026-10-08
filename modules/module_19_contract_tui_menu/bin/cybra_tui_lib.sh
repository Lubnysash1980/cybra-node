#!/data/data/com.termux/files/usr/bin/bash
# CYBRA TUI Library — спільні функції

CYBRA_MOD19_ROOT="$HOME/CYBRA/modules/module_19_contract_tui_menu"
CYBRA_CONTRACTS="$CYBRA_MOD19_ROOT/contracts"
CYBRA_LINKS="$CYBRA_MOD19_ROOT/links"
CYBRA_DEBUG="$CYBRA_MOD19_ROOT/evidence/debug.log"
CYBRA_LICENSE_LEDGER="$CYBRA_MOD19_ROOT/evidence/license_ledger.txt"

LICENSE_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
LICENSE_PERCENT=1

mkdir -p "$CYBRA_CONTRACTS" "$CYBRA_LINKS" \
         "$(dirname "$CYBRA_DEBUG")" \
         "$(dirname "$CYBRA_LICENSE_LEDGER")"

# ------------------------------------------------------------
# Кольори (якщо підтримує термінал)
# ------------------------------------------------------------

if [ -t 1 ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
    C_GREY=$'\033[90m'
else
    C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_CYAN=""; C_GREY=""
fi

# ------------------------------------------------------------
# Утиліти
# ------------------------------------------------------------

cybra_now() {
    date -u +%Y-%m-%dT%H:%M:%SZ
}

cybra_log() {
    printf '%s | %s\n' "$(cybra_now)" "$*" >> "$CYBRA_DEBUG"
}

cybra_hash() {
    sha256sum | awk '{print $1}'
}

cybra_rand_id() {
    # 16 hex символів
    head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n'
}

# ------------------------------------------------------------
# Ліцензія
# ------------------------------------------------------------

cybra_calc_license() {
    local amount="$1"
    # amount у wei/найменших одиницях
    # 1% = amount * 100 / 10000
    if ! [[ "$amount" =~ ^[0-9]+$ ]]; then
        echo "0"
        return 1
    fi
    echo $(( amount * LICENSE_PERCENT / 100 ))
}

cybra_license_record() {
    local contract_id="$1"
    local amount="$2"
    local license="$3"

    printf '%s | %s | %s | %s | %s\n' \
        "$(cybra_now)" \
        "$contract_id" \
        "$amount" \
        "$license" \
        "$LICENSE_RECIPIENT" \
        >> "$CYBRA_LICENSE_LEDGER"

    cybra_log "LICENSE_RECORDED contract=$contract_id amount=$amount license=$license"
}

# ------------------------------------------------------------
# Контракт
# ------------------------------------------------------------

cybra_contract_path() {
    echo "$CYBRA_CONTRACTS/$1.env"
}

cybra_contract_exists() {
    [ -f "$(cybra_contract_path "$1")" ]
}

cybra_contract_create() {
    local buyer="$1"
    local seller="$2"
    local amount="$3"
    local token="$4"

    if [ -z "$buyer" ] || [ -z "$seller" ] || [ -z "$amount" ]; then
        echo "ERROR: buyer, seller, amount required"
        return 1
    fi

    if [ "$buyer" = "$seller" ]; then
        echo "ERROR: buyer and seller must be different"
        return 1
    fi

    if ! [[ "$amount" =~ ^[0-9]+$ ]] || [ "$amount" -le 0 ]; then
        echo "ERROR: amount must be positive integer"
        return 1
    fi

    local contract_id="C-$(date -u +%Y%m%d%H%M%S)-$(cybra_rand_id)"
    local license="$(cybra_calc_license "$amount")"
    local net=$(( amount - license ))
    local now="$(cybra_now)"

    local f="$(cybra_contract_path "$contract_id")"

    cat > "$f" <<EOF
CONTRACT_ID=$contract_id
CREATED_AT=$now
PATCH_ID=CYBRA-M19-PATCH-0001

BUYER=$buyer
SELLER=$seller
TOKEN=$token

AMOUNT_WEI=$amount
LICENSE_WEI=$license
NET_WEI=$net

LICENSE_PERCENT=1
LICENSE_BPS=100
LICENSE_RECIPIENT=$LICENSE_RECIPIENT
LICENSE_FROZEN=TRUE

CHAIN_ID=56
NETWORK=BSC_MAINNET

STAGE=DRAFT
STATUS=CREATED

BUYER_CONFIRMED=FALSE
SELLER_CONFIRMED=FALSE
RECEIPT_CONFIRMED=FALSE

BUYER_CONFIRMED_AT=
SELLER_CONFIRMED_AT=
RECEIPT_CONFIRMED_AT=

BUYER_LINK_ID=
SELLER_LINK_ID=
RECEIPT_LINK_ID=

BUYER_LINK_HASH=
SELLER_LINK_HASH=
RECEIPT_LINK_HASH=

REAL_TRANSACTION_SENT=FALSE
GLOBAL_TRUE_100=FALSE
EOF

    # Ліцензія — в ledger
    cybra_license_record "$contract_id" "$amount" "$license"

    cybra_log "CONTRACT_CREATED id=$contract_id buyer=$buyer seller=$seller amount=$amount license=$license"

    echo "$contract_id"
}

# ------------------------------------------------------------
# Лінки
# ------------------------------------------------------------

cybra_link_path() {
    echo "$CYBRA_LINKS/$1.link"
}

cybra_link_generate() {
    local contract_id="$1"
    local role="$2"     # BUYER | SELLER | RECEIPT

    if ! cybra_contract_exists "$contract_id"; then
        echo "ERROR: contract not found"
        return 1
    fi

    case "$role" in
        BUYER|SELLER|RECEIPT) ;;
        *) echo "ERROR: role must be BUYER|SELLER|RECEIPT"; return 1 ;;
    esac

    local link_id="L-$role-$(cybra_rand_id)"
    local now="$(cybra_now)"
    local payload="CYBRA|$contract_id|$role|$now|$link_id"
    local link_hash="$(printf '%s' "$payload" | cybra_hash)"

    local lf="$(cybra_link_path "$link_id")"

    cat > "$lf" <<EOF
LINK_ID=$link_id
CONTRACT_ID=$contract_id
ROLE=$role
CREATED_AT=$now
STATUS=PENDING
LINK_HASH=$link_hash
LINK_PAYLOAD=$payload
CONFIRMED_AT=
CONFIRMED_BY=
EOF

    # Оновлюємо контракт — записуємо link_id
    local cf="$(cybra_contract_path "$contract_id")"

    case "$role" in
        BUYER)
            sed -i "s|^BUYER_LINK_ID=.*|BUYER_LINK_ID=$link_id|" "$cf"
            sed -i "s|^BUYER_LINK_HASH=.*|BUYER_LINK_HASH=$link_hash|" "$cf"
            ;;
        SELLER)
            sed -i "s|^SELLER_LINK_ID=.*|SELLER_LINK_ID=$link_id|" "$cf"
            sed -i "s|^SELLER_LINK_HASH=.*|SELLER_LINK_HASH=$link_hash|" "$cf"
            ;;
        RECEIPT)
            sed -i "s|^RECEIPT_LINK_ID=.*|RECEIPT_LINK_ID=$link_id|" "$cf"
            sed -i "s|^RECEIPT_LINK_HASH=.*|RECEIPT_LINK_HASH=$link_hash|" "$cf"
            ;;
    esac

    # Змінюємо stage
    if grep -q '^STAGE=DRAFT' "$cf"; then
        sed -i "s|^STAGE=DRAFT|STAGE=LINKED|" "$cf"
    fi

    cybra_log "LINK_GENERATED contract=$contract_id role=$role link_id=$link_id hash=$link_hash"

    echo "$link_id"
}

cybra_link_confirm() {
    local link_id="$1"
    local confirmer="$2"

    local lf="$(cybra_link_path "$link_id")"
    if [ ! -f "$lf" ]; then
        echo "ERROR: link not found"
        return 1
    fi

    local status="$(grep '^STATUS=' "$lf" | cut -d= -f2)"
    if [ "$status" = "CONFIRMED" ]; then
        echo "ERROR: link already confirmed"
        return 1
    fi

    local contract_id="$(grep '^CONTRACT_ID=' "$lf" | cut -d= -f2)"
    local role="$(grep '^ROLE=' "$lf" | cut -d= -f2)"
    local now="$(cybra_now)"

    sed -i "s|^STATUS=.*|STATUS=CONFIRMED|" "$lf"
    sed -i "s|^CONFIRMED_AT=.*|CONFIRMED_AT=$now|" "$lf"
    sed -i "s|^CONFIRMED_BY=.*|CONFIRMED_BY=$confirmer|" "$lf"

    # Оновлюємо контракт
    local cf="$(cybra_contract_path "$contract_id")"

    case "$role" in
        BUYER)
            sed -i "s|^BUYER_CONFIRMED=.*|BUYER_CONFIRMED=TRUE|" "$cf"
            sed -i "s|^BUYER_CONFIRMED_AT=.*|BUYER_CONFIRMED_AT=$now|" "$cf"
            if grep -q '^STAGE=LINKED' "$cf"; then
                sed -i "s|^STAGE=LINKED|STAGE=BUYER_OK|" "$cf"
            fi
            ;;
        SELLER)
            sed -i "s|^SELLER_CONFIRMED=.*|SELLER_CONFIRMED=TRUE|" "$cf"
            sed -i "s|^SELLER_CONFIRMED_AT=.*|SELLER_CONFIRMED_AT=$now|" "$cf"
            if grep -q '^STAGE=BUYER_OK' "$cf"; then
                sed -i "s|^STAGE=BUYER_OK|STAGE=SELLER_OK|" "$cf"
            fi
            ;;
        RECEIPT)
            sed -i "s|^RECEIPT_CONFIRMED=.*|RECEIPT_CONFIRMED=TRUE|" "$cf"
            sed -i "s|^RECEIPT_CONFIRMED_AT=.*|RECEIPT_CONFIRMED_AT=$now|" "$cf"
            if grep -q '^STAGE=SELLER_OK' "$cf"; then
                sed -i "s|^STAGE=SELLER_OK|STAGE=RECEIPT_OK|" "$cf"
            fi
            ;;
    esac

    # Перевіряємо чи COMPLETE
    local b="$(grep '^BUYER_CONFIRMED=' "$cf" | cut -d= -f2)"
    local s="$(grep '^SELLER_CONFIRMED=' "$cf" | cut -d= -f2)"
    local r="$(grep '^RECEIPT_CONFIRMED=' "$cf" | cut -d= -f2)"

    if [ "$b" = "TRUE" ] && [ "$s" = "TRUE" ] && [ "$r" = "TRUE" ]; then
        sed -i "s|^STAGE=.*|STAGE=COMPLETE|" "$cf"
        sed -i "s|^STATUS=.*|STATUS=COMPLETE|" "$cf"
        cybra_log "CONTRACT_COMPLETE id=$contract_id"
    fi

    cybra_log "LINK_CONFIRMED link_id=$link_id role=$role by=$confirmer"

    echo "OK: $role confirmed for $contract_id"
}
