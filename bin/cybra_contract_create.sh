#!/data/data/com.termux/files/usr/bin/bash
# ПРЯМИЙ writer — без меню, без інтерактиву
set -eu
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1

BUYER="${1:-}"; SELLER="${2:-}"; AMOUNT="${3:-}"; TOKEN="${4:-BNB}"
[ -z "$BUYER" ] || [ -z "$SELLER" ] || [ -z "$AMOUNT" ] && {
  echo '{"status":"error","error":"usage: create <buyer> <seller> <amount> [token]"}'
  exit 1
}

EPOCH=$(date +%s)
RAND=$(head -c 8 /dev/urandom | xxd -p)
CID="C-$EPOCH-$RAND"
mkdir -p public/contracts links evidence

LICENSE_WEI=$(( ${AMOUNT%%.*} / 100 ))
NET_WEI=$(( ${AMOUNT%%.*} - LICENSE_WEI ))

cat > "public/contracts/$CID.env" <<ENV
CONTRACT_ID=$CID
CREATED_AT=$(date -u +%FT%TZ)
PATCH_ID=CYBRA-M19-PATCH-0001
BUYER=$BUYER
SELLER=$SELLER
TOKEN=$TOKEN
AMOUNT_WEI=$AMOUNT
LICENSE_WEI=$LICENSE_WEI
NET_WEI=$NET_WEI
LICENSE_PERCENT=1
LICENSE_BPS=100
LICENSE_RECIPIENT=0x66434c5501242ccC71b5a39C765892921624B66c
LICENSE_FROZEN=TRUE
CHAIN_ID=56
NETWORK=BSC_MAINNET
STAGE=CREATED
REFUND_STATUS=pending
ENV

cat > "public/contracts/$CID.json" <<JSON
{"id":"$CID","buyer":"$BUYER","seller":"$SELLER","amount_wei":"$AMOUNT","token":"$TOKEN","stage":"CREATED","created_at":"$(date -u +%FT%TZ)"}
JSON

for role in buyer seller; do
  LID="L-$(date +%s)-$(head -c6 /dev/urandom | xxd -p)"
  cat > "links/$CID.$role.link" <<LNK
{"id":"$LID","contract_id":"$CID","role":"$role","confirmed":false,"created_at":"$(date -u +%FT%TZ)"}
LNK
done

echo "{\"status\":\"ok\",\"contract_id\":\"$CID\",\"env\":\"public/contracts/$CID.env\"}"
