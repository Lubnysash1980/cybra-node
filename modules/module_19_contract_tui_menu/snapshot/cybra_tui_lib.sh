#!/data/data/com.termux/files/usr/bin/bash
# CYBRA TUI Library — canonical

CYBRA_MOD19_ROOT="$HOME/CYBRA/modules/module_19_contract_tui_menu"
CYBRA_CONTRACTS="$CYBRA_MOD19_ROOT/contracts"
CYBRA_LINKS="$CYBRA_MOD19_ROOT/links"
CYBRA_DEBUG="$CYBRA_MOD19_ROOT/evidence/debug.log"
CYBRA_LICENSE_LEDGER="$CYBRA_MOD19_ROOT/evidence/license_ledger.txt"
CYBRA_LICENSE_LEDGER_B="$CYBRA_MOD19_ROOT/evidence/license_ledger_b.txt"
CYBRA_CREATION_LEDGER="$CYBRA_MOD19_ROOT/evidence/creation_license_ledger.txt"

LICENSE_A_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
LICENSE_A_PERCENT=1
LICENSE_A_BPS=100

LICENSE_B_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
LICENSE_B_PERCENT=1
LICENSE_B_BPS=100

DUAL_LICENSE_ENABLED=TRUE

LICENSE_RECIPIENT="$LICENSE_A_RECIPIENT"
LICENSE_PERCENT="$LICENSE_A_PERCENT"

CREATION_FEE_ENABLED=TRUE
CREATION_FEE_RECIPIENT="0x66434c5501242ccC71b5a39C765892921624B66c"
CREATION_FEE_PERCENT=1
CREATION_FEE_BPS=100
CREATION_FEE_FIXED_WEI=0
CREATION_FEE_MIN_WEI=0
CREATION_FEE_MAX_WEI=0

mkdir -p "$CYBRA_CONTRACTS" "$CYBRA_LINKS" "$(dirname "$CYBRA_DEBUG")"

[ -f "$CYBRA_LICENSE_LEDGER" ] || touch "$CYBRA_LICENSE_LEDGER"
[ -f "$CYBRA_LICENSE_LEDGER_B" ] || touch "$CYBRA_LICENSE_LEDGER_B"
[ -f "$CYBRA_CREATION_LEDGER" ] || touch "$CYBRA_CREATION_LEDGER"

if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'; C_GREY=$'\033[90m'
else
    C_RESET=""; C_BOLD=""; C_RED=""; C_GREEN=""
    C_YELLOW=""; C_BLUE=""; C_CYAN=""; C_GREY=""
fi

cybra_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
cybra_log() { printf '%s | %s\n' "$(cybra_now)" "$*" >> "$CYBRA_DEBUG"; }
cybra_hash() { sha256sum | awk '{print $1}'; }
cybra_rand_id() { head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n'; }

cybra_calc_license() {
    local amount="$1"
    [[ "$amount" =~ ^[0-9]+$ ]] || { echo 0; return 1; }
    echo $(( amount * LICENSE_A_PERCENT / 100 ))
}

cybra_calc_creation_fee() {
    local amount="$1"
    [[ "$amount" =~ ^[0-9]+$ ]] || { echo 0; return 1; }
    local var=$(( amount * CREATION_FEE_PERCENT / 100 ))
    echo $(( CREATION_FEE_FIXED_WEI + var ))
}

cybra_license_record() {
    local cid="$1" amt="$2" la="$3" lb="$4"
    printf '%s | %s | A | %s | %s | %s\n' "$(cybra_now)" "$cid" "$amt" "$la" "$LICENSE_A_RECIPIENT" >> "$CYBRA_LICENSE_LEDGER"
    printf '%s | %s | B | %s | %s | %s\n' "$(cybra_now)" "$cid" "$amt" "$lb" "$LICENSE_B_RECIPIENT" >> "$CYBRA_LICENSE_LEDGER_B"
    cybra_log "LICENSE_RECORDED $cid A=$la B=$lb"
}

cybra_creation_license_record() {
    local cid="$1" amt="$2" fee="$3" buyer="$4"
    printf '%s | %s | %s | %s | %s | %s\n' "$(cybra_now)" "$cid" "$buyer" "$amt" "$fee" "$CREATION_FEE_RECIPIENT" >> "$CYBRA_CREATION_LEDGER"
    cybra_log "CREATION_LICENSE $cid fee=$fee"
}

cybra_contract_path() { echo "$CYBRA_CONTRACTS/$1.env"; }
cybra_contract_exists() { [ -f "$(cybra_contract_path "$1")" ]; }

cybra_contract_create() {
    local buyer="$1" seller="$2" amount="$3" token="$4"
    local decimals="${5:-18}"

    [ -z "$buyer" ] && { echo "ERROR: buyer required" >&2; return 1; }
    [ -z "$seller" ] && { echo "ERROR: seller required" >&2; return 1; }
    [ -z "$amount" ] && { echo "ERROR: amount required" >&2; return 1; }
    [ "$buyer" = "$seller" ] && { echo "ERROR: buyer=seller" >&2; return 1; }
    [[ "$amount" =~ ^[0-9]+$ ]] && [ "$amount" -gt 0 ] || { echo "ERROR: amount>0" >&2; return 1; }

    local cid="C-$(date -u +%Y%m%d%H%M%S)-$(cybra_rand_id)"
    local la="$(cybra_calc_license "$amount")"
    local lb="$(cybra_calc_license "$amount")"
    local cf="$(cybra_calc_creation_fee "$amount")"
    local total=$(( la + lb + cf ))
    local net=$(( amount - total ))
    local now="$(cybra_now)"
    local f="$CYBRA_CONTRACTS/$cid.env"

    cat > "$f" <<CTR
CONTRACT_ID=$cid
CREATED_AT=$now
PATCH_ID=CYBRA-M19-PATCH-0002

BUYER=$buyer
SELLER=$seller
TOKEN=$token
TOKEN_DECIMALS=$decimals

AMOUNT_WEI=$amount
LICENSE_A_WEI=$la
LICENSE_A_PERCENT=1
LICENSE_A_BPS=100
LICENSE_A_RECIPIENT=$LICENSE_A_RECIPIENT
LICENSE_B_WEI=$lb
LICENSE_B_PERCENT=1
LICENSE_B_BPS=100
LICENSE_B_RECIPIENT=$LICENSE_B_RECIPIENT
CREATION_FEE_WEI=$cf
CREATION_FEE_PERCENT=$CREATION_FEE_PERCENT
CREATION_FEE_FIXED_WEI=$CREATION_FEE_FIXED_WEI
CREATION_FEE_RECIPIENT=$CREATION_FEE_RECIPIENT
CREATION_FEE_BUYER=$buyer
CREATION_FEE_FROZEN=TRUE
LICENSE_TOTAL_WEI=$total
NET_WEI=$net
DUAL_LICENSE_FROZEN=TRUE

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
CTR

    cybra_license_record "$cid" "$amount" "$la" "$lb"
    cybra_creation_license_record "$cid" "$amount" "$cf" "$buyer"
    cybra_log "CONTRACT_CREATED $cid"

    echo "$cid"
}

cybra_link_path() { echo "$CYBRA_LINKS/$1.link"; }

cybra_link_generate() {
    local cid="$1" role="$2"

    cybra_contract_exists "$cid" || { echo "ERROR: contract not found" >&2; return 1; }
    case "$role" in BUYER|SELLER|RECEIPT) ;; *) echo "ERROR: role" >&2; return 1 ;; esac

    local lid="L-$role-$(cybra_rand_id)"
    local now="$(cybra_now)"
    local payload="CYBRA|$cid|$role|$now|$lid"
    local lh="$(printf '%s' "$payload" | cybra_hash)"
    local lf="$CYBRA_LINKS/$lid.link"

    cat > "$lf" <<LNK
LINK_ID=$lid
CONTRACT_ID=$cid
ROLE=$role
CREATED_AT=$now
STATUS=PENDING
LINK_HASH=$lh
LINK_PAYLOAD=$payload
CONFIRMED_AT=
CONFIRMED_BY=
LNK

    local cf="$CYBRA_CONTRACTS/$cid.env"
    case "$role" in
        BUYER)   sed -i "s|^BUYER_LINK_ID=.*|BUYER_LINK_ID=$lid|" "$cf"; sed -i "s|^BUYER_LINK_HASH=.*|BUYER_LINK_HASH=$lh|" "$cf" ;;
        SELLER)  sed -i "s|^SELLER_LINK_ID=.*|SELLER_LINK_ID=$lid|" "$cf"; sed -i "s|^SELLER_LINK_HASH=.*|SELLER_LINK_HASH=$lh|" "$cf" ;;
        RECEIPT) sed -i "s|^RECEIPT_LINK_ID=.*|RECEIPT_LINK_ID=$lid|" "$cf"; sed -i "s|^RECEIPT_LINK_HASH=.*|RECEIPT_LINK_HASH=$lh|" "$cf" ;;
    esac
    grep -q '^STAGE=DRAFT' "$cf" && sed -i "s|^STAGE=DRAFT|STAGE=LINKED|" "$cf"

    cybra_log "LINK_GENERATED $cid $role $lid"
    echo "$lid"
}

cybra_link_confirm() {
    local lid="$1" who="$2"
    local lf="$CYBRA_LINKS/$lid.link"
    [ -f "$lf" ] || { echo "ERROR: link not found" >&2; return 1; }

    local status="$(grep '^STATUS=' "$lf" | cut -d= -f2)"
    [ "$status" = "CONFIRMED" ] && { echo "ERROR: already confirmed" >&2; return 1; }

    local cid="$(grep '^CONTRACT_ID=' "$lf" | cut -d= -f2)"
    local role="$(grep '^ROLE=' "$lf" | cut -d= -f2)"
    local now="$(cybra_now)"

    sed -i "s|^STATUS=.*|STATUS=CONFIRMED|" "$lf"
    sed -i "s|^CONFIRMED_AT=.*|CONFIRMED_AT=$now|" "$lf"
    sed -i "s|^CONFIRMED_BY=.*|CONFIRMED_BY=$who|" "$lf"

    local cf="$CYBRA_CONTRACTS/$cid.env"
    case "$role" in
        BUYER)   sed -i "s|^BUYER_CONFIRMED=.*|BUYER_CONFIRMED=TRUE|" "$cf"; sed -i "s|^BUYER_CONFIRMED_AT=.*|BUYER_CONFIRMED_AT=$now|" "$cf"; grep -q '^STAGE=LINKED' "$cf" && sed -i "s|^STAGE=LINKED|STAGE=BUYER_OK|" "$cf" ;;
        SELLER)  sed -i "s|^SELLER_CONFIRMED=.*|SELLER_CONFIRMED=TRUE|" "$cf"; sed -i "s|^SELLER_CONFIRMED_AT=.*|SELLER_CONFIRMED_AT=$now|" "$cf"; grep -q '^STAGE=BUYER_OK' "$cf" && sed -i "s|^STAGE=BUYER_OK|STAGE=SELLER_OK|" "$cf" ;;
        RECEIPT) sed -i "s|^RECEIPT_CONFIRMED=.*|RECEIPT_CONFIRMED=TRUE|" "$cf"; sed -i "s|^RECEIPT_CONFIRMED_AT=.*|RECEIPT_CONFIRMED_AT=$now|" "$cf"; grep -q '^STAGE=SELLER_OK' "$cf" && sed -i "s|^STAGE=SELLER_OK|STAGE=RECEIPT_OK|" "$cf" ;;
    esac

    local b="$(grep '^BUYER_CONFIRMED=' "$cf" | cut -d= -f2)"
    local s="$(grep '^SELLER_CONFIRMED=' "$cf" | cut -d= -f2)"
    local r="$(grep '^RECEIPT_CONFIRMED=' "$cf" | cut -d= -f2)"
    if [ "$b" = "TRUE" ] && [ "$s" = "TRUE" ] && [ "$r" = "TRUE" ]; then
        sed -i "s|^STAGE=.*|STAGE=COMPLETE|" "$cf"
        sed -i "s|^STATUS=.*|STATUS=COMPLETE|" "$cf"
        cybra_log "CONTRACT_COMPLETE $cid"
    fi

    cybra_log "LINK_CONFIRMED $lid $role by=$who"
    echo "OK: $role confirmed for $cid"
}

# Aliases для тестів
CREATION_LICENSE_LEDGER="$CYBRA_CREATION_LEDGER"
LICENSE_LEDGER="$CYBRA_LICENSE_LEDGER"
LICENSE_LEDGER_B="$CYBRA_LICENSE_LEDGER_B"
export CREATION_LICENSE_LEDGER LICENSE_LEDGER LICENSE_LEDGER_B

# ------------------------------------------------------------
# AMOUNT CONVERTER: human → wei (з decimals)
# ------------------------------------------------------------

cybra_amount_to_wei() {
    local input="$1"
    local decimals="${2:-18}"

    # Якщо чисте ціле і decimals=0 — повертаємо як є
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        # Якщо decimals=18 і число < 1e6 — ймовірно це wei вже
        if [ "$decimals" = "18" ] && [ "${#input}" -ge 15 ]; then
            echo "$input"
            return 0
        fi
        # Інакше — множимо на 10^decimals
        local mult="1"
        local i=0
        while [ "$i" -lt "$decimals" ]; do
            mult="${mult}0"
            i=$((i+1))
        done
        echo $(( input * 10**decimals )) 2>/dev/null || echo "$input$mult"
        return 0
    fi

    # Десятковий формат
    if [[ "$input" =~ ^[0-9]+\.[0-9]+$ ]]; then
        local whole="${input%.*}"
        local frac="${input#*.}"

        while [ "${#frac}" -lt "$decimals" ]; do
            frac="${frac}0"
        done
        frac="${frac:0:$decimals}"

        [ -z "$whole" ] && whole="0"
        local result="${whole}${frac}"
        result="$(printf '%s' "$result" | sed 's/^0*//')"
        [ -z "$result" ] && result="0"
        echo "$result"
        return 0
    fi

    echo "0"
    return 1
}
