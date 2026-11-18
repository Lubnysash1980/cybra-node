#!/data/data/com.termux/files/usr/bin/bash
. barmenu/lib/colors.sh
title "═══ ПАРАМЕТРИ .env ═══"
grep -E "^(TOKEN_ADDR|QUOTE_ADDR|FEE_TIER|AMOUNT_HUMAN|WALLET_ADDRESS|BSC_RPC_URL)=" .env
echo ""
read -p "Змінити (AMOUNT_HUMAN/PRICE_INCREASE/QUOTE_ADDR/FEE_TIER) або Enter: " K
[ -z "$K" ] && exit 0
read -p "Нове значення: " V

VALID=true
case "$K" in
  AMOUNT_HUMAN) [[ "$V" =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$V >= 0.0001" | bc -l) )) || { err "Має бути число >= 0.0001"; VALID=false; } ;;
  FEE_TIER) [[ "$V" == "500" || "$V" == "2500" || "$V" == "10000" ]] || { err "Тільки 500/2500/10000"; VALID=false; } ;;
  QUOTE_ADDR|TOKEN_ADDR|WALLET_ADDRESS) [[ "$V" =~ ^0x[a-fA-F0-9]{40}$ ]] || { err "Адреса має бути 0x + 40 hex"; VALID=false; } ;;
  *) err "Невідомий параметр"; VALID=false ;;
esac

if [ "$VALID" = "true" ]; then
    grep -q "^$K=" .env && sed -i "s|^$K=.*|$K=$V|" .env || echo "$K=$V" >> .env
    ok "✅ $K = $V"
fi
