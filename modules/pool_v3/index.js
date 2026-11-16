const { ethers } = require('ethers');
const { Token, Percent } = require('@pancakeswap/swap-sdk-core');
const { ChainId } = require('@pancakeswap/chains');
const { Pool, Position, NonfungiblePositionManager, FeeAmount, nearestUsableTick } = require('@pancakeswap/v3-sdk');

const autofix = require('../autofix');
const NFPM_V3 = '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364';
const FACTORY_V3 = '0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865';
const CHAIN_ID = 'eip155:56';
const MIN_TICK = -887272;
const MAX_TICK = 887272;

module.exports = {
  name: 'pool_v3',
  async run(ctx) {
    const { provider, signClient, session, account, env } = ctx;
    const { TOKEN_ADDR, QUOTE_ADDR, AMOUNT_HUMAN } = env;
    const FEE_TIER = parseInt(env.FEE_TIER || '2500', 10);
    const PRICE_INCREASE = parseInt(env.PRICE_INCREASE || '100', 10);

    if (!TOKEN_ADDR || !QUOTE_ADDR || !AMOUNT_HUMAN) throw new Error('❌ Відсутні TOKEN_ADDR/QUOTE_ADDR/AMOUNT_HUMAN в .env');

    const erc20Abi = ['function decimals() view returns (uint8)', 'function approve(address,uint) returns (bool)', 'function allowance(address,address) view returns (uint)'];
    const decT = await new ethers.Contract(TOKEN_ADDR, erc20Abi, provider).decimals();
    const decQ = await new ethers.Contract(QUOTE_ADDR, erc20Abi, provider).decimals();

    let t0, t1, d0, d1;
    if (TOKEN_ADDR.toLowerCase() < QUOTE_ADDR.toLowerCase()) { t0 = TOKEN_ADDR; t1 = QUOTE_ADDR; d0 = decT; d1 = decQ; }
    else { t0 = QUOTE_ADDR; t1 = TOKEN_ADDR; d0 = decQ; d1 = decT; }
    const isToken0 = TOKEN_ADDR.toLowerCase() === t0.toLowerCase();
    console.log(`[pool_v3] Твій токен = token${isToken0 ? '0' : '1'}`);

    const factory = new ethers.Contract(FACTORY_V3, ['function getPool(address,address,uint24) view returns (address)'], provider);
    let poolAddress = await factory.getPool(t0, t1, FEE_TIER);

    if (poolAddress === ethers.ZeroAddress) {
      console.log(`[pool_v3] 🆕 Пул не існує. Створюємо...`);
      const Q96 = BigInt(2) ** BigInt(96);
      const nfpm = new ethers.Contract(NFPM_V3, ['function createAndInitializePoolIfNecessary(address,address,uint24,uint160) payable returns (address)'], provider);
      const data = nfpm.interface.encodeFunctionData('createAndInitializePoolIfNecessary', [t0, t1, FEE_TIER, Q96.toString()]);
      await signClient.request({ topic: session.topic, chainId: CHAIN_ID, request: { method: 'eth_sendTransaction', params: [{ from: account, to: NFPM_V3, data, value: '0x0' }] } });
      await new Promise(r => setTimeout(r, 5000));
      poolAddress = await factory.getPool(t0, t1, FEE_TIER);
    }
    if (poolAddress === ethers.ZeroAddress) throw new Error('Пул не створено.');
    console.log(`[pool_v3] ✅ Пул: ${poolAddress}`);

    const poolContract = new ethers.Contract(poolAddress, ['function slot0() view returns (uint160, int24, uint16, uint16, uint16, uint32, bool)', 'function liquidity() view returns (uint128)'], provider);
    const slot0 = await poolContract.slot0();
    const liq = await poolContract.liquidity();
    const currentTick = Number(slot0[1]);
    const sqrtPriceX96 = slot0[0].toString();

    const token0 = new Token(ChainId.BSC, t0, Number(d0));
    const token1 = new Token(ChainId.BSC, t1, Number(d1));
    const pool = new Pool(token0, token1, FEE_TIER, sqrtPriceX96, liq.toString(), currentTick);

    const delta = Math.round(Math.log(1 + PRICE_INCREASE / 100) / Math.log(1.0001));
    let tickLower, tickUpper;
    if (isToken0) {
      tickLower = nearestUsableTick(currentTick + pool.tickSpacing, pool.tickSpacing);
      tickUpper = nearestUsableTick(tickLower + delta, pool.tickSpacing);
    } else {
      tickUpper = nearestUsableTick(currentTick - pool.tickSpacing, pool.tickSpacing);
      tickLower = nearestUsableTick(tickUpper - delta, pool.tickSpacing);
    }
    if (tickLower < MIN_TICK) tickLower = nearestUsableTick(MIN_TICK, pool.tickSpacing);
    if (tickUpper > MAX_TICK) tickUpper = nearestUsableTick(MAX_TICK, pool.tickSpacing);
    console.log(`[pool_v3] Діапазон: [${tickLower}, ${tickUpper}] (тік ${currentTick})`);

    const amountDesired = ethers.parseUnits(AMOUNT_HUMAN, isToken0 ? d0 : d1);
    let position;
    if (isToken0) {
      position = Position.fromAmount0({ pool, tickLower, tickUpper, amount0: amountDesired.toString(), useFullPrecision: false });
    } else {
      position = Position.fromAmount1({ pool, tickLower, tickUpper, amount1: amountDesired.toString(), useFullPrecision: false });
    }

    const MAX_UINT = ethers.MaxUint256;
    if (position.mintAmounts.amount0 === MAX_UINT || position.mintAmounts.amount1 === MAX_UINT) {
      throw new Error('SDK MaxUint256 — перевір PRICE_INCREASE діапазон');
    }
    const mintA0 = BigInt(position.mintAmounts.amount0.toString());
    const mintA1 = BigInt(position.mintAmounts.amount1.toString());
    console.log(`[pool_v3] Потрібно: amount0=${mintA0}, amount1=${mintA1}`);

    if (mintA0 === 0n && mintA1 === 0n) throw new Error('❌ Ліквідність = 0. Зміни PRICE_INCREASE/AMOUNT_HUMAN.');

    for (const [addr, amt] of [[t0, mintA0], [t1, mintA1]]) {
      if (amt > 0n) {
        const erc20 = new ethers.Contract(addr, erc20Abi, provider);
        const allow = await erc20.allowance(account, NFPM_V3);
        if (allow < amt) {
          console.log(`[pool_v3] 👉 Approve ${amt} для ${addr.substring(0,10)}...`);
          const data = erc20.interface.encodeFunctionData('approve', [NFPM_V3, amt.toString()]);
          await signClient.request({ topic: session.topic, chainId: CHAIN_ID, request: { method: 'eth_sendTransaction', params: [{ from: account, to: addr, data, value: '0x0' }] } });
          await new Promise(r => setTimeout(r, 4000));
        }
      }
    }

    const { calldata, value } = NonfungiblePositionManager.addCallParameters(position, {
      slippageTolerance: new Percent(5, 1000), recipient: account, deadline: Math.floor(Date.now() / 1000) + 600
    });

    console.log(`[pool_v3] 👉 Mint`);
    const txHash = await signClient.request({ topic: session.topic, chainId: CHAIN_ID, request: { method: 'eth_sendTransaction', params: [{ from: account, to: NFPM_V3, data: calldata, value, gas: '0x2dc6c0' }] } });
    console.log(`[pool_v3] ⏳ Чекаємо TX...`);
    const receipt = await provider.waitForTransaction(txHash);
    if (!receipt || receipt.status !== 1) throw new Error(`Mint failed: ${txHash}`);
    console.log(`[pool_v3] 🎉 Успіх! TX: ${txHash}`);
    return { success: true, poolAddress, txHash };
  }
};
