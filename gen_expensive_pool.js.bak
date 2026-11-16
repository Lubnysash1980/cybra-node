require('dotenv').config();
const { ethers } = require('ethers');
const { Token } = require('@pancakeswap/swap-sdk-core');
const { ChainId } = require('@pancakeswap/chains');
const { Pool, nearestUsableTick } = require('@pancakeswap/v3-sdk');

(async () => {
  const provider = new ethers.JsonRpcProvider(process.env.BSC_RPC_URL || 'https://bsc-rpc.publicnode.com');
  const TOKEN_ADDR = process.env.TOKEN_ADDR; // CYBRA
  const QUOTE_ADDR = process.env.QUOTE_ADDR; // USDT
  const FEE_TIER = parseInt(process.env.FEE_TIER || '2500');

  // Сортуємо токени (USDT - token0, CYBRA - token1)
  const t0 = TOKEN_ADDR.toLowerCase() < QUOTE_ADDR.toLowerCase() ? TOKEN_ADDR : QUOTE_ADDR;
  const t1 = TOKEN_ADDR.toLowerCase() < QUOTE_ADDR.toLowerCase() ? QUOTE_ADDR : TOKEN_ADDR;
  const isToken0 = TOKEN_ADDR.toLowerCase() === t0.toLowerCase();

  const factory = new ethers.Contract('0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865', ['function getPool(address,address,uint24) view returns (address)'], provider);
  const poolAddress = await factory.getPool(t0, t1, FEE_TIER);
  
  const poolContract = new ethers.Contract(poolAddress, ['function slot0() view returns (uint160, int24, uint16, uint16, uint16, uint32, bool)'], provider);
  const slot0 = await poolContract.slot0();
  const currentTick = Number(slot0[1]);

  // Цільова ціна: 1 CYBRA = 400 000 000 USDT
  // Формула V3: Price = token1 / token0. Оскільки token1 = CYBRA, а token0 = USDT, 
  // ціна в пулі буде 1 / 400 000 000 = 0.0000000025
  const targetPrice = 1 / 400000000; 
  
  // Розрахунок тіку для цільової ціни
  const targetTick = Math.round(Math.log(targetPrice) / Math.log(1.0001));

  // Створюємо діапазон навколо цільової ціни (наприклад, +/- 1000 тіків)
  const tickSpacing = 50; // для 0.25% комісії
  const tickLower = nearestUsableTick(targetTick - 1000, tickSpacing);
  const tickUpper = nearestUsableTick(targetTick + 1000, tickSpacing);

  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 година
  
  // Кількість токенів, яку ти хочеш внести (наприклад, 100 CYBRA)
  const amountToSell = process.env.AMOUNT_HUMAN || '100';
  const amountWei = ethers.parseUnits(amountToSell, isToken0 ? 18 : 18); // припускаємо 18 decimals

  console.log('\n=== СКОПІЮЙ ЦІ ДАНІ ДЛЯ ДРУГОГО ПУЛУ (MINT) ===');
  console.log(`token0:        ${t0}`);
  console.log(`token1:        ${t1}`);
  console.log(`fee:           ${FEE_TIER}`);
  console.log(`tickLower:     ${tickLower}`);
  console.log(`tickUpper:     ${tickUpper}`);
  // Оскільки цільова ціна вище ринку, ми вносимо ТІЛЬКИ CYBRA (token1)
  console.log(`amount0Desired:0`);
  console.log(`amount1Desired:${!isToken0 ? amountWei.toString() : '0'}`);
  console.log(`amount0Min:    0`);
  console.log(`amount1Min:    ${!isToken0 ? (amountWei * 995n / 1000n).toString() : '0'}`);
  console.log(`recipient:     ${process.env.WALLET_ADDRESS || '0x9f6b6054d74052c98142a4c3797a078eddd48c58'}`);
  console.log(`deadline:      ${deadline}`);
  console.log('================================================\n');
  console.log(`📊 Поточний тік: ${currentTick}`);
  console.log(`📊 Цільовий тік для 400M USDT: ${targetTick}`);
})();
