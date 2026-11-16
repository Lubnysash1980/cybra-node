require('dotenv').config();
const { ethers } = require('ethers');

const FACTORY = '0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865';
const ZERO = ethers.ZeroAddress;

const ERC20 = [
  'function decimals() view returns (uint8)',
  'function symbol() view returns (string)',
  'function name() view returns (string)'
];

const FACTORY_ABI = [
  'function getPool(address,address,uint24) view returns (address)',
  'function feeAmountTickSpacing(uint24) view returns (int24)'
];

const POOL_ABI = [
  'function slot0() view returns (uint160,int24,uint16,uint16,uint16,uint32,bool)',
  'function liquidity() view returns (uint128)',
  'function token0() view returns (address)',
  'function token1() view returns (address)',
  'function fee() view returns (uint24)'
];

async function main() {
  const provider = new ethers.JsonRpcProvider(process.env.BSC_RPC_URL);

  const token = process.env.TOKEN_ADDR;
  const quote = process.env.QUOTE_ADDR;
  const fee = Number(process.env.FEE_TIER || 2500);

  if (!ethers.isAddress(token) || !ethers.isAddress(quote))
    throw new Error('Invalid token address');

  const network = await provider.getNetwork();

  console.log('\n===== CYBRA MINT DIAGNOSTIC v2 =====');
  console.log('Chain ID:', network.chainId.toString());

  if (network.chainId !== 56n)
    throw new Error('RPC is not connected to BNB Smart Chain');

  const t0 = token.toLowerCase() < quote.toLowerCase()
    ? token : quote;

  const t1 = token.toLowerCase() < quote.toLowerCase()
    ? quote : token;

  const c0 = new ethers.Contract(t0, ERC20, provider);
  const c1 = new ethers.Contract(t1, ERC20, provider);

  const [d0, d1, s0, s1, n0, n1] = await Promise.all([
    c0.decimals(), c1.decimals(),
    c0.symbol(), c1.symbol(),
    c0.name(), c1.name()
  ]);

  console.log('\n--- TOKENS ---');
  console.log('Token0:', s0, n0, t0);
  console.log('Decimals0:', d0);
  console.log('Token1:', s1, n1, t1);
  console.log('Decimals1:', d1);

  const factory = new ethers.Contract(
    FACTORY, FACTORY_ABI, provider
  );

  const [poolAddress, spacing] = await Promise.all([
    factory.getPool(t0, t1, fee),
    factory.feeAmountTickSpacing(fee)
  ]);

  console.log('\n--- POOL ---');
  console.log('Fee:', fee);
  console.log('Tick spacing:', spacing.toString());
  console.log('Pool:', poolAddress);

  if (poolAddress === ZERO)
    throw new Error('Pool does not exist for these tokens and fee');

  const code = await provider.getCode(poolAddress);

  if (code === '0x')
    throw new Error('Pool address has no contract code');

  const pool = new ethers.Contract(
    poolAddress, POOL_ABI, provider
  );

  const [slot, liquidity, actual0, actual1, actualFee] =
    await Promise.all([
      pool.slot0(),
      pool.liquidity(),
      pool.token0(),
      pool.token1(),
      pool.fee()
    ]);

  if (
    actual0.toLowerCase() !== t0.toLowerCase() ||
    actual1.toLowerCase() !== t1.toLowerCase()
  ) throw new Error('Pool token order mismatch');

  const sqrt = Number(slot[0]) / (2 ** 96);
  const rawPrice = sqrt * sqrt;

  const price1Per0 =
    rawPrice * (10 ** Number(d0)) / (10 ** Number(d1));

  const price0Per1 = 1 / price1Per0;

  console.log('\n--- LIVE STATE ---');
  console.log('Current tick:', slot[1].toString());
  console.log('sqrtPriceX96:', slot[0].toString());
  console.log('Initialized:', slot[6]);
  console.log('Liquidity:', liquidity.toString());

  console.log('\n--- NORMALIZED PRICE ---');
  console.log(`${s1} per ${s0}:`, price1Per0);
  console.log(`${s0} per ${s1}:`, price0Per1);

  console.log('\n--- 400M TARGET ---');
  const target = 400000000;
  const targetPrice = 1 / target;
  const targetTick = Math.round(
    Math.log(targetPrice) / Math.log(1.0001)
  );

  console.log('Target:', target, s0, 'per', s1);
  console.log('Target tick:', targetTick);
  console.log('Current tick:', Number(slot[1]));
  console.log('Tick difference:',
    Number(slot[1]) - targetTick
  );

  console.log('\n--- SAFETY CHECK ---');

  if (Number(slot[1]) > targetTick + 1000) {
    console.log('WARNING: Target range is below current price.');
    console.log('A V3 position there generally requires token0, not token1.');
  } else if (Number(slot[1]) < targetTick - 1000) {
    console.log('Target range is above current price.');
    console.log('A V3 position there generally requires token1.');
  } else {
    console.log('Current price is near target range.');
  }

  console.log('\nREAD ONLY: NO TRANSACTIONS SENT.');
  console.log('===== DIAGNOSTIC COMPLETE =====\n');
}

main().catch(err => {
  console.error('\nDIAGNOSTIC ERROR:', err.message);
  process.exitCode = 1;
});
