#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 CONTRACT_AMOUNT"
    exit 1
fi

AMOUNT="$1"

case "$AMOUNT" in
    ''|*[!0-9]*)
        echo "ERROR: CONTRACT_AMOUNT must be a positive integer"
        exit 1
        ;;
esac

if [ "$AMOUNT" -le 0 ]; then
    echo "ERROR: CONTRACT_AMOUNT must be > 0"
    exit 1
fi

LICENSE_BPS=100

LICENSE_AMOUNT=$(( AMOUNT * LICENSE_BPS / 10000 ))
NET_AMOUNT=$(( AMOUNT - LICENSE_AMOUNT ))

echo "CONTRACT_AMOUNT=$AMOUNT"
echo "LICENSE_BPS=$LICENSE_BPS"
echo "LICENSE_PERCENT=1"
echo "LICENSE_AMOUNT=$LICENSE_AMOUNT"
echo "NET_CONTRACT_AMOUNT=$NET_AMOUNT"
