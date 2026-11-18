#!/data/data/com.termux/files/usr/bin/bash
. barmenu/lib/colors.sh
clear
title "═══ COLLECT FEES ДЛЯ BSCSCAN ═══"
read -p "NFT tokenId (з пункту 3): " TOKENID
[ -z "$TOKENID" ] && exit 0

WALLET=$(grep "^WALLET_ADDRESS=" .env | cut -d= -f2 || echo "0x9f6b6054d74052c98142a4c3797a078eddd48c58")

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  COLLECT у BscScan → Write Contract → collect              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "  tokenId:         $TOKENID"
echo "  recipient:       $WALLET"
echo "  amount0Max:      340282366920938463463374607431768211455"
echo "  amount1Max:      340282366920938463463374607431768211455"
echo ""
echo "🔗 BscScan: https://bscscan.com/address/0x46A15B0b27311cedF172AB29E4f4766fbE7F4364#writeContract"
echo ""
info "340282366... це MaxUint128 — дозволяє забрати всі комісії"
