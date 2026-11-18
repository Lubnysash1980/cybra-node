#!/data/data/com.termux/files/usr/bin/bash
. barmenu/lib/colors.sh
clear
title "╔══════════════════════════════════════════════╗"
title "║  🎯 ГЕНЕРАТОР MINT ДЛЯ BSCSCAN              ║"
title "╚══════════════════════════════════════════════╝"
echo ""

# Читаємо .env
TOKEN_ADDR=$(grep "^TOKEN_ADDR=" .env | cut -d= -f2)
QUOTE_ADDR=$(grep "^QUOTE_ADDR=" .env | cut -d= -f2)
FEE_TIER=$(grep "^FEE_TIER=" .env | cut -d= -f2)
AMOUNT=$(grep "^AMOUNT_HUMAN=" .env | cut -d= -f2)
WALLET=$(grep "^WALLET_ADDRESS=" .env | cut -d= -f2 || echo "0x9f6b6054d74052c98142a4c3797a078eddd48c58")

info "Поточні параметри:"
echo "  Токен: $TOKEN_ADDR"
echo "  Пара:  $QUOTE_ADDR"
echo "  Комісія: $FEE_TIER"
echo "  Кількість: $AMOUNT"
echo ""

read -p "Цільова ціна в USDT (напр. 1000 або 400000000): " TARGET_USDT
[ -z "$TARGET_USDT" ] && exit 0

# Розрахунок через Node.js (точно як у V3)
node -e "
require('dotenv').config();
const { ethers } = require('ethers');
const { Token } = require('@pancakeswap/swap-sdk-core');
const { ChainId } = require('@pancakeswap/chains');
const { Pool, nearestUsableTick } = require('@pancakeswap/v3-sdk');

(async () => {
  const provider = new ethers.JsonRpcProvider(process.env.BSC_RPC_URL);
  const TOKEN_ADDR = process.env.TOKEN_ADDR;
  const QUOTE_ADDR = process.env.QUOTE_ADDR;
  const FEE_TIER = parseInt(process.env.FEE_TIER);
  const AMOUNT = process.env.AMOUNT_HUMAN;
  const TARGET_USDT = Number('$TARGET_USDT');

  const erc20Abi = ['function decimals() view returns (uint8)'];
  const decT = await new ethers.Contract(TOKEN_ADDR, erc20Abi, provider).decimals();
  const decQ = await new ethers.Contract(QUOTE_ADDR, erc20Abi, provider).decimals();

  const t0 = TOKEN_ADDR.toLowerCase() < QUOTE_ADDR.toLowerCase() ? TOKEN_ADDR : QUOTE_ADDR;
  const t1 = TOKEN_ADDR.toLowerCase() < QUOTE_ADDR.toLowerCase() ? QUOTE_ADDR : TOKEN_ADDR;
  const isToken0 = TOKEN_ADDR.toLowerCase() === t0.toLowerCase();

  const factory = new ethers.Contract('0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865', ['function getPool(address,address,uint24) view returns (address)'], provider);
  const poolAddress = await factory.getPool(t0, t1, FEE_TIER);
  if (poolAddress === ethers.ZeroAddress) {
    console.log('❌ Пул не існує. Спочатку створи його через createAndInitializePoolIfNecessary');
    process.exit(1);
  }

  const poolContract = new ethers.Contract(poolAddress, ['function slot0() view returns (uint160, int24, uint16, uint16, uint16, uint32, bool)'], provider);
  const slot0 = await poolContract.slot0();
  const currentTick = Number(slot0[1]);
  const tickSpacing = FEE_TIER === 500 ? 10 : FEE_TIER === 2500 ? 50 : 200;

  // Target price → tick
  const targetPrice = 1 / TARGET_USDT;
  const targetTick = Math.round(Math.log(targetPrice) / Math.log(1.0001));
  
  const tickLower = Math.floor((targetTick - 1000) / tickSpacing) * tickSpacing;
  const tickUpper = Math.ceil((targetTick + 1000) / tickSpacing) * tickSpacing;

  const amountDesired = ethers.parseUnits(AMOUNT, isToken0 ? decT : decQ);
  const deadline = Math.floor(Date.now() / 1000) + 3600;

  console.log('');
  console.log('╔════════════════════════════════════════════════════════════╗');
  console.log('║  СКОПІЮЙ ЦЕ У BSCSCAN → Write Contract → mint              ║');
  console.log('╚════════════════════════════════════════════════════════════╝');
  console.log('');
  console.log('  token0:          ' + t0);
  console.log('  token1:          ' + t1);
  console.log('  fee:             ' + FEE_TIER);
  console.log('  tickLower:       ' + tickLower);
  console.log('  tickUpper:       ' + tickUpper);
  console.log('  amount0Desired:  ' + (isToken0 ? amountDesired.toString() : '0'));
  console.log('  amount1Desired:  ' + (!isToken0 ? amountDesired.toString() : '0'));
  console.log('  amount0Min:      0');
  console.log('  amount1Min:      ' + (amountDesired * 995n / 1000n).toString());
  console.log('  recipient:       ' + (process.env.WALLET_ADDRESS || '0x9f6b6054d74052c98142a4c3797a078eddd48c58'));
  console.log('  deadline:        ' + deadline);
  console.log('');
  console.log('📊 Цільова ціна: $' + TARGET_USDT.toLocaleString('en-US') + ' за токен');
  console.log('📊 targetTick = ' + targetTick);
  console.log('📊 Поточний тік: ' + currentTick);
  console.log('');
  console.log('🔗 BscScan: https://bscscan.com/address/0x46A15B0b27311cedF172AB29E4f4766fbE7F4364#writeContract');
})();
"
