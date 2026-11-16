require('dotenv').config();
const { ethers } = require('ethers');
const { Token } = require('@pancakeswap/swap-sdk-core');
const { ChainId } = require('@pancakeswap/chains');
const { Pool, Position, nearestUsableTick } = require('@pancakeswap/v3-sdk');

(async () => {
  const provider = new ethers.JsonRpcProvider(process.env.BSC_RPC_URL || 'https://bsc-rpc.publicnode.com');
  const NFPM_V3 = '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364';
  const TOKEN_ADDR = process.env.TOKEN_ADDR;
  const QUOTE_ADDR = process.env.QUOTE_ADDR;
  const FEE_TIER = parseInt(process.env.FEE_TIER || '2500');
  const AMOUNT = process.env.AMOUNT_HUMAN;
  const PRICE_INC = parseInt(process.env.PRICE_INCREASE || '100');

  const erc20Abi = ['function decimals() view returns (uint8)'];
  const decT = await new ethers.Contract(TOKEN_ADDR, erc20Abi, provider).decimals();
  const decQ = await new ethers.Contract(QUOTE_ADDR, erc20Abi, provider).decimals();

  const t0 = TOKEN_ADDR.toLowerCase() < QUOTE_ADDR.toLowerCase() ? TOKEN_ADDR : QUOTE_ADDR;
  const t1 = TOKEN_ADDR.toLowerCase() < QUOTE_ADDR.toLowerCase() ? QUOTE_ADDR : TOKEN_ADDR;
  const isToken0 = TOKEN_ADDR.toLowerCase() === t0.toLowerCase();

  const factory = new ethers.Contract('0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865', ['function getPool(address,address,uint24) view returns (address)'], provider);
  const poolAddress = await factory.getPool(t0, t1, FEE_TIER);
  const poolContract = new ethers.Contract(poolAddress, ['function slot0() view returns (uint160, int24, uint16, uint16, uint16, uint32, bool)', 'function liquidity() view returns (uint128)'], provider);
  
  const slot0 = await poolContract.slot0();
  const liq = await poolContract.liquidity();
  const currentTick = Number(slot0[1]);

  const token0 = new Token(ChainId.BSC, t0, Number(decT));
  const token1 = new Token(ChainId.BSC, t1, Number(decQ));
  const pool = new Pool(token0, token1, FEE_TIER, slot0[0].toString(), liq.toString(), currentTick);

  const delta = Math.round(Math.log(1 + PRICE_INC / 100) / Math.log(1.0001));
  let tickLower, tickUpper;
  if (isToken0) {
    tickLower = nearestUsableTick(currentTick + pool.tickSpacing, pool.tickSpacing);
    tickUpper = nearestUsableTick(tickLower + delta, pool.tickSpacing);
  } else {
    tickUpper = nearestUsableTick(currentTick - pool.tickSpacing, pool.tickSpacing);
    tickLower = nearestUsableTick(tickUpper - delta, pool.tickSpacing);
  }

  const amountDesired = ethers.parseUnits(AMOUNT, isToken0 ? decT : decQ);
  let position;
  if (isToken0) position = Position.fromAmount0({ pool, tickLower, tickUpper, amount0: amountDesired.toString(), useFullPrecision: false });
  else position = Position.fromAmount1({ pool, tickLower, tickUpper, amount1: amountDesired.toString(), useFullPrecision: false });

  const deadline = Math.floor(Date.now() / 1000) + 3600; // 1 година

  console.log('\n=== СКОПІЮЙ ЦІ ДАНІ У BSCSCAN ===');
  console.log(`token0:        ${t0}`);
  console.log(`token1:        ${t1}`);
  console.log(`fee:           ${FEE_TIER}`);
  console.log(`tickLower:     ${tickLower}`);
  console.log(`tickUpper:     ${tickUpper}`);
  console.log(`amount0Desired:${isToken0 ? amountDesired.toString() : '0'}`);
  console.log(`amount1Desired:${!isToken0 ? amountDesired.toString() : '0'}`);
  console.log(`amount0Min:    0`);
  console.log(`amount1Min:    ${!isToken0 ? (BigInt(amountDesired.toString()) * 995n / 1000n).toString() : '0'}`); // 0.5% slippage
  console.log(`recipient:     ${process.env.WALLET_ADDRESS || '0x9f6b6054d74052c98142a4c3797a078eddd48c58'}`);
  console.log(`deadline:      ${deadline}`);
  console.log('==================================\n');
})();
