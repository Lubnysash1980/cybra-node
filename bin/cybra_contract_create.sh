#!/data/data/com.termux/files/usr/bin/bash
# Прямий contract creator БЕЗ меню. Пише .env + links + json.
set -eu
CYBRA="$HOME/CYBRA"; cd "$CYBRA" || exit 1

BUYER="${1:-}"; SELLER="${2:-}"; AMOUNT="${3:-}"; TOKEN="${4:-BNB}"

[ -z "$BUYER" ] || [ -z "$SELLER" ] || [ -z "$AMOUNT" ] && {
  echo '{"error":"usage: cybra_contract_create.sh <buyer> <seller> <amount_wei> [token=BNB]"}'
  exit 1
}

# contract id
EPOCH=$(date +%s)
RAND=$(head -c 8 /dev/urandom | xxd -p)
CID="C-$EPOCH-$RAND"

mkdir -p public/contracts links evidence

# ─── .env (основний формат) ───
ENV="public/contracts/$CID.env"
LICENSE_WEI=$(( ${AMOUNT%%.*} / 100 ))
NET_WEI=$(( ${AMOUNT%%.*} - LICENSE_WEI ))
{
  echo "CONTRACT_ID=$CID"
  echo "CREATED_AT=$(date -u +%FT%TZ)"
  echo "PATCH_ID=CYBRA-M19-PATCH-0001"
  echo "BUYER=$BUYER"
  echo "SELLER=$SELLER"
  echo "TOKEN=$TOKEN"
  echo "AMOUNT_WEI=$AMOUNT"
  echo "LICENSE_WEI=$LICENSE_WEI"
  echo "NET_WEI=$NET_WEI"
  echo "LICENSE_PERCENT=1"
  echo "LICENSE_BPS=100"
  echo "LICENSE_RECIPIENT=0x66434c5501242ccC71b5a39C765892921624B66c"
  echo "LICENSE_FROZEN=TRUE"
  echo "CHAIN_ID=56"
  echo "NETWORK=BSC_MAINNET"
  echo "STAGE=CREATED"
  echo "BUYER_FINAL_DECISION="
  echo "REFUND_STATUS=pending"
} > "$ENV"

# ─── .json (для скриптів) ───
JSON="public/contracts/$CID.json"
cat > "$JSON" <<JSON
{
  "id": "$CID",
  "buyer": "$BUYER",
  "seller": "$SELLER",
  "amount_wei": "$AMOUNT",
  "token": "$TOKEN",
  "stage": "CREATED",
  "created_at": "$(date -u +%FT%TZ)",
  "refund_status": "pending"
}
JSON

# ─── links (buyer + seller) ───
for role in buyer seller; do
  LID="L-$(date +%s)-$(head -c6 /dev/urandom | xxd -p)"
  LINK="links/$CID.$role.link"
  cat > "$LINK" <<LNK
{
  "id": "$LID",
  "contract_id": "$CID",
  "role": "$role",
  "confirmed": false,
  "created_at": "$(date -u +%FT%TZ)"
}
LNK
done

echo "{\"status\":\"ok\",\"contract_id\":\"$CID\",\"env\":\"$ENV\",\"json\":\"$JSON\",\"links\":2}"
