require('dotenv').config();
const { ethers } = require('ethers');
const { SignClient } = require('@walletconnect/sign-client');
const qrcode = require('qrcode-terminal');
const { input, select, confirm } = require('@inquirer/prompts');
const { Token } = require('@pancakeswap/swap-sdk-core');
const { ChainId } = require('@pancakeswap/chains');
const { Pool, Position, NonfungiblePositionManager, FeeAmount, nearestUsableTick, Percent } = require('@pancakeswap/v3-sdk');

// ========== КОНСТАНТИ ==========
const CHAIN_ID = 'eip155:56';
const NFPM_V3 = '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364';
const FACTORY_V3 = '0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865';
const MAX_TICK = 887272;

// RPC URL (переконайтеся, що у .env вказано стабільний RPC, наприклад від Ankr)
const RPC_URL = process.env.BSC_RPC_URL || 'https://bsc-rpc.publicnode.com';

let provider, rpcUrl, signClient, session, account;

// ========== ABI ІНТЕРФЕЙСИ ==========
const factoryInterface = new ethers.Interface(['function getPool(address,address,uint24) view returns (address)']);
const nfpmInterface = new ethers.Interface(['function createAndInitializePoolIfNecessary(address,address,uint24,uint160) payable returns (address)']);
const poolInterface = new ethers.Interface([
  'function slot0() view returns (uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, uint32, bool)',
  'function liquidity() view returns (uint128)'
]);

// ========== 1. RPC ==========
async function initProvider() {
  console.log(`⏳ Підключення до RPC: ${RPC_URL.substring(0, 50)}...`);
  try {
    provider = new ethers.JsonRpcProvider(RPC_URL);
    const block = await provider.getBlockNumber();
    console.log(`✅ RPC успішно підключено! Поточний блок: ${block}`);
    return;
  } catch (e) {
    console.error(`❌ Не вдалося підключитися до RPC: ${e.message}`);
    process.exit(1);
  }
}

// ========== 2. ГАМАНЕЦЬ (ОНОВЛЕНО: ОКРЕМІ ЛІНКИ) ==========
async function connectWallet() {
  signClient = await SignClient.init({
    projectId: process.env.WC_PROJECT_ID,
    metadata: { name: 'Pancake V3 Ultimate AutoFix', description: 'Termux', url: 'https://localhost', icons: [] },
  });
  
  const { uri, approval } = await signClient.connect({
    optionalNamespaces: { eip155: { methods: ['eth_sendTransaction'], chains: [CHAIN_ID], events: [] } },
  });

  console.log('\n📱 Відскануйте QR-код у гаманці:');
  qrcode.generate(uri, { small: true });

  // Кодуємо URI для передачі в посилання
  const encodedUri = encodeURIComponent(uri);

  console.log('\n🔗 АБО НАТИСНІТЬ НА ПОСИЛАННЯ НИЖЧЕ (в Termux вони клікабельні):');
  
  // --- ОКРЕМИЙ ЛІНК ДЛЯ METAMASK ---
  console.log('\n🦊 MetaMask:');
  console.log(`   https://metamask.app.link/wc?uri=${encodedUri}`);
  console.log(`   (Альтернатива, якщо вище не працює):`);
  console.log(`   metamask://wc?uri=${encodedUri}`);

  // --- ОКРЕМИЙ ЛІНК ДЛЯ TRUST WALLET ---
  console.log('\n🛡️ Trust Wallet:');
  console.log(`   https://link.trustwallet.com/wc?uri=${encodedUri}`);
  
  console.log('\n⏳ Очікуємо підтвердження підключення в гаманці...');
  
  session = await approval();
  account = session.namespaces.eip155.accounts[0].split(':')[2];
  console.log('\n✅ Гаманець успішно підключено:', account);
}

// ========== 3. ВІДПРАВКА ТА СИРІ ВИКЛИКИ ==========
async function sendTx(tx, actionName = 'Транзакція') {
  console.log(`\n👉 Підтвердіть у гаманці: ${actionName}`);
  const hash = await signClient.request({
    topic: session.topic, chainId: CHAIN_ID,
    request: { method: 'eth_sendTransaction', params: [tx] },
  });
  console.log(`📤 Відправлено: ${hash}`);
  await new Promise(r => setTimeout(r, 4000));
  return hash;
}

async function safeGetPool(token0, token1, fee) {
  const data = factoryInterface.encodeFunctionData('getPool', [token0, token1, fee]);
  try {
    const res = await provider.call({ to: FACTORY_V3, data });
    if (!res || res === '0x' || res === '0x0') throw new Error('EMPTY_RESPONSE');
    return factoryInterface.decodeFunctionResult('getPool', res)[0];
  } catch (e) {
    if (e.code === 'BUFFER_OVERRUN' || e.message.includes('cannot slice') || e.message === 'EMPTY_RESPONSE') {
      console.log('⚠️ RPC повернув порожні дані. Повторна спроба...');
      await new Promise(r => setTimeout(r, 2000));
      return safeGetPool(token0, token1, fee);
    }
    throw e;
  }
}

async function safeCheckCreatePool(token0, token1, fee, sqrtPriceX96) {
  const data = nfpmInterface.encodeFunctionData('createAndInitializePoolIfNecessary', [token0, token1, fee, sqrtPriceX96]);
  try {
    await provider.call({ from: account, to: NFPM_V3, data });
    return true;
  } catch (e) {
    if (e.code === 'BUFFER_OVERRUN' || e.message.includes('cannot slice') || e.data === '0x' || e.message.includes('reverted')) {
      return false;
    }
    throw e;
  }
}

// ========== 4. АВТО-ФІКС ЗАХИСТУ ТОКЕНА ==========
async function autoFixTokenRestrictions(tokenAddr) {
  console.log('\n🛠️ ЗАПУСК АВТО-ФІКСУ ЗАХИСТУ ТОКЕНА...');
  const fixAbi = [
    'function enableTrading()', 'function openTrading()', 'function setTradingEnabled(bool)',
    'function setMaxTxAmount(uint256)', 'function excludeFromFee(address)', 'function setAutomatedMarketMakerPair(address,bool)'
  ];
  const contract = new ethers.Contract(tokenAddr, fixAbi, provider);
  const maxAmount = ethers.parseUnits('1000000000', 18);

  const fixesToTry = [
    { name: 'enableTrading()', data: contract.interface.encodeFunctionData('enableTrading') },
    { name: 'openTrading()', data: contract.interface.encodeFunctionData('openTrading') },
    { name: 'setTradingEnabled(true)', data: contract.interface.encodeFunctionData('setTradingEnabled', [true]) },
    { name: 'setMaxTxAmount(велике число)', data: contract.interface.encodeFunctionData('setMaxTxAmount', [maxAmount]) },
    { name: 'excludeFromFee(NFPM_V3)', data: contract.interface.encodeFunctionData('excludeFromFee', [NFPM_V3]) },
    { name: 'setAutomatedMarketMakerPair(NFPM_V3, true)', data: contract.interface.encodeFunctionData('setAutomatedMarketMakerPair', [NFPM_V3, true]) }
  ];

  let fixedAny = false;
  for (const fix of fixesToTry) {
    try {
      await provider.call({ from: account, to: tokenAddr, data: fix.data });
      console.log(`\n✅ Знайдено функцію: ${fix.name}`);
      const confirmFix = await confirm({ message: `Виконати ${fix.name} для розблокування?` });
      if (confirmFix) {
        await sendTx({ from: account, to: tokenAddr, data: fix.data, value: '0x0' }, fix.name);
        fixedAny = true;
      }
    } catch (e) {}
  }

  if (fixedAny) {
    console.log('⏳ Чекаємо 6 секунд для оновлення блокчейну...');
    await new Promise(r => setTimeout(r, 6000));
  } else {
    console.log('⚠️ Стандартних функцій не знайдено. Можливо, у вас інший захист.');
  }
}

// ========== 5. ОСНОВНА ЛОГІКА СТВОРЕННЯ ПУЛУ ==========
async function createV3PoolAndPosition(tokenAddr, quoteAddr, feeTier, amountHuman, priceIncreasePercent) {
  const erc20Abi = ['function decimals() view returns (uint8)'];
  const decToken = await new ethers.Contract(tokenAddr, erc20Abi, provider).decimals();
  const decQuote = await new ethers.Contract(quoteAddr, erc20Abi, provider).decimals();

  let token0Addr, token1Addr, dec0, dec1;
  if (tokenAddr.toLowerCase() < quoteAddr.toLowerCase()) {
    token0Addr = tokenAddr; token1Addr = quoteAddr; dec0 = decToken; dec1 = decQuote;
  } else {
    token0Addr = quoteAddr; token1Addr = tokenAddr; dec0 = decQuote; dec1 = decToken;
  }

  const token0 = new Token(ChainId.BSC, token0Addr, Number(dec0));
  const token1 = new Token(ChainId.BSC, token1Addr, Number(dec1));

  console.log('\n⏳ Перевіряємо наявність пулу...');
  let poolAddress = await safeGetPool(token0Addr, token1Addr, feeTier);

  if (poolAddress === ethers.ZeroAddress) {
    console.log('🆕 Пул не існує. Перевіряємо можливість створення...');
    const Q96 = BigInt(2) ** BigInt(96);
    const canCreate = await safeCheckCreatePool(token0Addr, token1Addr, feeTier, Q96);

    if (!canCreate) {
      console.log('\n❌ Контракт токена заблокував створення пулу!');
      await autoFixTokenRestrictions(tokenAddr);
      console.log('\n🔄 Повторна спроба створення пулу...');
      const data = nfpmInterface.encodeFunctionData('createAndInitializePoolIfNecessary', [token0Addr, token1Addr, feeTier, Q96.toString()]);
      try {
        await sendTx({ from: account, to: NFPM_V3, data, value: '0x0' }, 'Створення пулу V3');
      } catch (e) { console.log('⚠️ Гаманець відхилив транзакцію.'); }
    } else {
      console.log('✅ Перевірка пройдена. Створюємо пул...');
      const data = nfpmInterface.encodeFunctionData('createAndInitializePoolIfNecessary', [token0Addr, token1Addr, feeTier, Q96.toString()]);
      await sendTx({ from: account, to: NFPM_V3, data, value: '0x0' }, 'Створення пулу V3');
    }

    console.log('⏳ Чекаємо 5 секунд...');
    await new Promise(r => setTimeout(r, 5000));
    poolAddress = await safeGetPool(token0Addr, token1Addr, feeTier);
  }

  if (poolAddress === ethers.ZeroAddress) throw new Error('Пул досі не створено.');

  console.log('✅ Пул існує:', poolAddress);

  const slot0Data = poolInterface.encodeFunctionData('slot0');
  const liqData = poolInterface.encodeFunctionData('liquidity');
  const [slot0Res, liqRes] = await Promise.all([
    provider.call({ to: poolAddress, data: slot0Data }),
    provider.call({ to: poolAddress, data: liqData })
  ]);
  const slot0 = poolInterface.decodeFunctionResult('slot0', slot0Res);
  const liquidity = poolInterface.decodeFunctionResult('liquidity', liqRes)[0];

  const pool = new Pool(token0, token1, feeTier, slot0.sqrtPriceX96.toString(), liquidity.toString(), slot0.tick);
  const tickSpacing = pool.tickSpacing;
  const delta = Math.round(Math.log(1 + priceIncreasePercent / 100) / Math.log(1.0001));

  let tickLower = nearestUsableTick(slot0.tick + delta, tickSpacing);
  let tickUpper = nearestUsableTick(slot0.tick + delta * 2, tickSpacing);
  if (tickLower <= slot0.tick) {
    tickLower = nearestUsableTick(slot0.tick + tickSpacing, tickSpacing);
    tickUpper = nearestUsableTick(slot0.tick + tickSpacing * 2, tickSpacing);
  }

  const isToken0 = tokenAddr.toLowerCase() === token0Addr.toLowerCase();
  const amountDesired = ethers.parseUnits(amountHuman, isToken0 ? dec0 : dec1);

  const position = Position.fromAmounts({
    pool, tickLower, tickUpper, amount0: isToken0 ? amountDesired.toString() : '0', amount1: !isToken0 ? amountDesired.toString() : '0', useFullPrecision: false,
  });

  const mintAmounts = position.mintAmounts;
  
  for (const [addr, amt] of [[token0Addr, mintAmounts.amount0], [token1Addr, mintAmounts.amount1]]) {
    if (BigInt(amt.toString()) > 0n) {
      const erc20 = new ethers.Contract(addr, ['function allowance(address,address) view returns (uint)', 'function approve(address,uint) returns (bool)'], provider);
      const allow = await erc20.allowance(account, NFPM_V3);
      if (allow < BigInt(amt.toString())) {
        await sendTx({ from: account, to: addr, data: erc20.interface.encodeFunctionData('approve', [NFPM_V3, amt.toString()]), value: '0x0' }, `Approve для ${addr}`);
      }
    }
  }

  const { calldata, value } = NonfungiblePositionManager.addCallParameters(position, {
    slippageTolerance: new Percent(5, 1000), recipient: account, deadline: Math.floor(Date.now() / 1000) + 600,
  });

  await sendTx({ from: account, to: NFPM_V3, data: calldata, value, gas: '0x2dc6c0' }, 'Створення позиції (Mint)');
  console.log('🎉 Позицію успішно створено!');
}

// ========== ЗАПУСК ==========
(async () => {
  if (!process.env.WC_PROJECT_ID) { console.error('❌ Додайте WC_PROJECT_ID у .env'); process.exit(1); }
  await initProvider();
  await connectWallet();

  const token = await input({ message: 'Адреса вашого токена (CYBRA):' });
  const quote = await input({ message: 'Адреса токена пари (USDT):', default: '0x55d398326f99059fF775485246999027B3197955' });
  const feeTier = await select({
    message: 'Рівень комісії:',
    choices: [{ name: '0.05%', value: FeeAmount.LOWEST }, { name: '0.25%', value: FeeAmount.MEDIUM }, { name: '1%', value: FeeAmount.HIGH }],
  });
  const amount = await input({ message: 'Кількість вашого токена (напр. 100):' });
  const increase = await input({ message: 'На скільки % вище ринку? (макс 1000):', default: '100' });

  try {
    await createV3PoolAndPosition(token, quote, feeTier, amount, Number(increase));
  } catch (e) {
    console.error('\n❌ Зупинка скрипта. Причина:', e.message);
  }
})();
