require('dotenv').config();
const { ethers } = require('ethers');
const { Token, Percent } = require('@pancakeswap/swap-sdk-core');
const { ChainId } = require('@pancakeswap/chains');
const { Pool, Position, NonfungiblePositionManager, nearestUsableTick } = require('@pancakeswap/v3-sdk');

const NFPM_V3 = '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364';
const FACTORY_V3 = '0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865';

// ✅ Вбудована логіка гаманця (без конфлікту з іншим модулем)
function getWallet(provider) {
  const pk = process.env.WALLET_PRIVATE_KEY;
  const seed = process.env.SECRET_RECOVERY_PHRASE || process.env.WALLET_MNEMONIC;

  if (pk && pk.trim().length >= 64) {
    const clean = pk.trim().startsWith('0x') ? pk.trim() : '0x' + pk.trim();
    console.log('[wallet] 🔑 WALLET_PRIVATE_KEY');
    return new ethers.Wallet(clean, provider);
  }
  if (seed && seed.trim().split(/\s+/).length >= 12) {
    console.log('[wallet] 🌱 SECRET_RECOVERY_PHRASE (сід-фраза)');
    const derived = ethers.Wallet.fromPhrase(seed.trim());
    return new ethers.Wallet(derived.privateKey, provider);
  }
  throw new Error('Немає WALLET_PRIVATE_KEY або SECRET_RECOVERY_PHRASE у .env');
}

async function main() {
  const provider = new ethers.JsonRpcProvider(process.env.BSC_RPC_URL || 'https://bsc-rpc.publicnode.com');
  
  const wallet = getWallet(provider);
  console.log(`🚀 АВТО-ПУЛ: ${wallet.address}`);
  const bnb = await provider.getBalance(wallet.address);
  console.log(`💰 BNB: ${ethers.formatEther(bnb)}`);

  const TOKEN_ADDR = process.env.TOKEN_ADDR;
  const QUOTE_ADDR = process.env.QUOTE_ADDR;
  const FEE_TIER = parseInt(process.env.FEE_TIER || '2500', 10);
  const AMOUNT_HUMAN = process.env.AMOUNT_HUMAN || '100';
  const TARGET_USDT = Number(process.env.TARGET_USDT || '1000');

  const erc20Abi = ['function decimals() view returns (uint8)', 'function approve(address,uint) returns (bool)', 'function allowance(address,address) view returns (uint)', 'function balanceOf(address) view returns (uint)'];
  const decT = await new ethers.Contract(TOKEN_ADDR, erc20Abi, provider).decimals();
  const decQ = await new ethers.Contract(QUOTE_ADDR, erc20Abi, provider).decimals();

  const t0 = TOKEN_ADDR.toLowerCase() < QUOTE_ADDR.toLowerCase() ? TOKEN_ADDR : QUOTE_ADDR;
  const t1 = TOKEN_ADDR.toLowerCase() < QUOTE_ADDR.toLowerCase() ? QUOTE_ADDR : TOKEN_ADDR;
  const isToken0 = TOKEN_ADDR.toLowerCase() === t0.toLowerCase();

  const factory = new ethers.Contract(FACTORY_V3, ['function getPool(address,address,uint24) view returns (address)'], provider);
  let poolAddress = await factory.getPool(t0, t1, FEE_TIER);
  if (poolAddress === ethers.ZeroAddress) {
    console.log('🆕 Ініціалізуємо пул...');
    const Q96 = BigInt(2) ** BigInt(96);
    const nfpm = new ethers.Contract(NFPM_V3, ['function createAndInitializePoolIfNecessary(address,address,uint24,uint160) payable returns (address)'], wallet);
    const tx = await nfpm.createAndInitializePoolIfNecessary(t0, t1, FEE_TIER, Q96.toString());
    console.log(`   TX: ${tx.hash}`);
    await tx.wait();
    poolAddress = await factory.getPool(t0, t1, FEE_TIER);
  }
  console.log(`✅ Пул: ${poolAddress}`);

  const poolContract = new ethers.Contract(poolAddress, ['function slot0() view returns (uint160, int24, uint16, uint16, uint16, uint32, bool)', 'function liquidity() view returns (uint128)'], provider);
  const slot0 = await poolContract.slot0();
  const currentTick = Number(slot0[1]);
  const spacing = FEE_TIER === 500 ? 10 : FEE_TIER === 2500 ? 50 : 200;

  const targetPrice = 1 / TARGET_USDT;
  const targetTick = Math.round(Math.log(targetPrice) / Math.log(1.0001));
  const tickLower = Math.floor((targetTick - 1000) / spacing) * spacing;
  const tickUpper = Math.ceil((targetTick + 1000) / spacing) * spacing;

  const amountDesired = ethers.parseUnits(AMOUNT_HUMAN, isToken0 ? decT : decQ);
  const token0 = new Token(ChainId.BSC, t0, Number(decT));
  const token1 = new Token(ChainId.BSC, t1, Number(decQ));
  const pool = new Pool(token0, token1, FEE_TIER, slot0[0].toString(), (await poolContract.liquidity()).toString(), currentTick);

  let position;
  if (isToken0) position = Position.fromAmount0({ pool, tickLower, tickUpper, amount0: amountDesired.toString(), useFullPrecision: false });
  else position = Position.fromAmount1({ pool, tickLower, tickUpper, amount1: amountDesired.toString(), useFullPrecision: false });

  const mintA0 = BigInt(position.mintAmounts.amount0.toString());
  const mintA1 = BigInt(position.mintAmounts.amount1.toString());
  console.log(`📊 token0: ${mintA0}, token1: ${mintA1}`);
  console.log(`📊 Тіки: [${tickLower}, ${tickUpper}], ціна $${TARGET_USDT}`);

  for (const [addr, amt, dec] of [[t0, mintA0, decT], [t1, mintA1, decQ]]) {
    if (amt > 0n) {
      const erc20 = new ethers.Contract(addr, erc20Abi, wallet);
      const bal = await erc20.balanceOf(wallet.address);
      if (bal < amt) throw new Error(`Недостатньо токенів ${addr}: маєш ${ethers.formatUnits(bal, dec)}, треба ${ethers.formatUnits(amt, dec)}`);
      if (await erc20.allowance(wallet.address, NFPM_V3) < amt) {
        console.log(`⏳ Approve ${addr.substring(0,10)}...`);
        await (await erc20.approve(NFPM_V3, amt)).wait();
        console.log(`   ✅ Approve OK`);
      }
    }
  }

  const { calldata, value } = NonfungiblePositionManager.addCallParameters(position, {
    slippageTolerance: new Percent(5, 1000), recipient: wallet.address, deadline: Math.floor(Date.now() / 1000) + 600
  });
  console.log(`⏳ MINT...`);
  const mintTx = await wallet.sendTransaction({ to: NFPM_V3, data: calldata, value });
  console.log(`📤 TX: https://bscscan.com/tx/${mintTx.hash}`);
  console.log(`🎉 ТРАНЗАКЦІЯ ВІДПРАВЛЕНА! Перевір на BscScan через 10-15 сек.`);
  console.log(`💡 Позиція з'явиться в гаманці як NFT після підтвердження.`);
}

main().catch(err => {
  console.error(`❌ ${err.message}`);
  try {
    const { execSync } = require('child_process');
    const safe = err.message.replace(/"/g, '\\"').substring(0, 200);
    execSync(`cybra-it task "[AUTO-POOL] ${safe}"`, { stdio: 'ignore' });
    console.log(`🏛️ Задача в Парламент`);
  } catch(e) {}
  process.exit(1);
});
