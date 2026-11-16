// Встановлення:
// pkg install nodejs-lts
// npm init -y
// npm install ethers @walletconnect/sign-client qrcode-terminal dotenv @inquirer/prompts @pancakeswap/v3-sdk @pancakeswap/swap-sdk-core @pancakeswap/chains @pancakeswap/tokens

require('dotenv').config();
const { ethers } = require('ethers');
const { SignClient } = require('@walletconnect/sign-client');
const qrcode = require('qrcode-terminal');
const { select, input, confirm } = require('@inquirer/prompts');
const { Pool, Position, NonfungiblePositionManager, FeeAmount, nearestUsableTick } = require('@pancakeswap/v3-sdk');
const { Token } = require('@pancakeswap/swap-sdk-core');
const { ChainId } = require('@pancakeswap/chains');
const { bscTokens } = require('@pancakeswap/tokens');

// ========== 1. RPC ТА КОНСТАНТИ ==========
const RPC_CANDIDATES = [
  'https://bsc-dataseed1.binance.org',
  'https://bsc-rpc.publicnode.com',
  'https://bsc.rpc.blxrbdn.com',
];
const CHAIN_ID = 'eip155:56';
const ROUTER_V2 = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
const NFPM_V3 = '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364';
const FACTORY_V3 = '0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865';

let provider, rpcUrl;

async function getWorkingProvider() {
  for (const url of RPC_CANDIDATES) {
    try {
      const p = new ethers.JsonRpcProvider(url);
      await p.getBlockNumber();
      console.log(`✅ RPC: ${url}`);
      return { provider: p, rpcUrl: url };
    } catch (e) { /* ignore */ }
  }
  throw new Error('Немає робочого RPC');
}

// ========== 2. WALLETCONNECT ==========
async function connectWallet(projectId) {
  const signClient = await SignClient.init({
    projectId,
    metadata: { name: 'AI Pool Manager', description: 'Termux AI DeFi', url: 'https://localhost', icons: [] },
  });
  const { uri, approval } = await signClient.connect({
    optionalNamespaces: {
      eip155: {
        methods: ['eth_sendTransaction', 'personal_sign'],
        chains: [CHAIN_ID],
        events: ['chainChanged', 'accountsChanged'],
      },
    },
  });
  console.log('\n📱 Відскануйте QR або перейдіть за посиланням:');
  console.log('Trust Wallet:', `https://link.trustwallet.com/wc?uri=${encodeURIComponent(uri)}`);
  console.log('MetaMask:', `https://metamask.app.link/wc?uri=${encodeURIComponent(uri)}`);
  qrcode.generate(uri, { small: true });
  const session = await approval();
  const account = session.namespaces.eip155.accounts[0].split(':')[2];
  console.log('✅ Гаманець:', account);
  return { signClient, session, account };
}

// ========== 3. ОТРИМАННЯ СПИСКУ ТОКЕНІВ ==========
// Варіант А: відомі токени PancakeSwap (USDT, CAKE, WBNB тощо)
const KNOWN_TOKENS = {
  'USDT (BSC)': bscTokens.usdt,
  'CAKE': bscTokens.cake,
  'WBNB': bscTokens.wbnb,
  'BUSD': bscTokens.busd,
};

async function chooseToken(account, signClient, session, label) {
  const mode = await select({
    message: `Оберіть спосіб вибору ${label}:`,
    choices: [
      { name: 'З відомого списку (USDT, CAKE, WBNB...)', value: 'known' },
      { name: 'Ввести адресу вручну', value: 'manual' },
      { name: 'Отримати баланси з гаманця (потрібен індексер)', value: 'wallet' },
    ],
  });

  if (mode === 'known') {
    const choice = await select({
      message: `Оберіть ${label}:`,
      choices: Object.keys(KNOWN_TOKENS).map((k) => ({ name: k, value: KNOWN_TOKENS[k] })),
    });
    return { address: choice.address, decimals: choice.decimals, symbol: choice.symbol };
  }

  if (mode === 'manual') {
    const addr = await input({ message: `Введіть адресу ${label}:` });
    const erc20 = new ethers.Contract(addr, ['function decimals() view returns (uint8)', 'function symbol() view returns (string)'], provider);
    const [dec, sym] = await Promise.all([erc20.decimals(), erc20.symbol()]);
    return { address: addr, decimals: dec, symbol: sym };
  }

  // Варіант з гаманця: отримуємо баланси для відомих токенів (спрощено)
  console.log('⏳ Отримання балансів (лише для відомих токенів)...');
  const balances = [];
  for (const [name, token] of Object.entries(KNOWN_TOKENS)) {
    const erc20 = new ethers.Contract(token.address, ['function balanceOf(address) view returns (uint)'], provider);
    const bal = await erc20.balanceOf(account);
    if (bal > 0n) balances.push({ name, token, balance: bal });
  }
  if (balances.length === 0) {
    console.log('ℹ️ На гаманці немає відомих токенів. Введіть адресу вручну.');
    return chooseToken(account, signClient, session, label); // рекурсія до ручного вводу
  }
  const chosen = await select({
    message: `Оберіть ${label} з балансом:`,
    choices: balances.map((b) => ({ name: `${b.name} (${ethers.formatUnits(b.balance, b.token.decimals)})`, value: b })),
  });
  return { address: chosen.token.address, decimals: chosen.token.decimals, symbol: chosen.token.symbol };
}

// ========== 4. ФУНКЦІЇ ДЛЯ V2 ТА V3 (СПРОЩЕНО) ==========
async function sendTxWithFix(signClient, session, tx) {
  try {
    const hash = await signClient.request({
      topic: session.topic,
      chainId: CHAIN_ID,
      request: { method: 'eth_sendTransaction', params: [tx] },
    });
    console.log('📤 Tx:', hash);
    return hash;
  } catch (e) {
    if (e.message.includes('gas')) {
      tx.gas = '0x2dc6c0'; // 3M
      return signClient.request({ topic: session.topic, chainId: CHAIN_ID, request: { method: 'eth_sendTransaction', params: [tx] } });
    }
    throw e;
  }
}

async function ensureApproval(tokenAddr, spender, amount, account, signClient, session) {
  const erc20 = new ethers.Contract(tokenAddr, ['function allowance(address,address) view returns (uint)', 'function approve(address,uint) returns (bool)'], provider);
  const allowance = await erc20.allowance(account, spender);
  if (allowance >= amount) return;
  console.log(`⏳ Approve ${tokenAddr}...`);
  const data = erc20.interface.encodeFunctionData('approve', [spender, amount]);
  await sendTxWithFix(signClient, session, { from: account, to: tokenAddr, data, value: '0x0' });
}

async function createV2Pool(params) {
  const { tokenA, tokenB, amountA, amountB, account, signClient, session } = params;
  const router = new ethers.Contract(ROUTER_V2, ['function addLiquidity(address,address,uint,uint,uint,uint,address,uint) returns (uint,uint,uint)'], provider);
  const deadline = Math.floor(Date.now() / 1000) + 600;
  const data = router.interface.encodeFunctionData('addLiquidity', [
    tokenA.address, tokenB.address, amountA, amountB, 0, 0, account, deadline,
  ]);
  await sendTxWithFix(signClient, session, { from: account, to: ROUTER_V2, data, value: '0x0' });
}

async function createV3Position(params) {
  const { token, quoteToken, feeTier, amountHuman, priceIncreasePercent, account, signClient, session } = params;

  const factory = new ethers.Contract(FACTORY_V3, ['function getPool(address,address,uint24) view returns (address)'], provider);
  const poolAddress = await factory.getPool(token.address, quoteToken.address, feeTier);
  if (poolAddress === ethers.ZeroAddress) throw new Error('Пул не існує. Спочатку створіть пул V3.');

  const poolContract = new ethers.Contract(poolAddress, [
    'function slot0() view returns (uint160 sqrtPriceX96, int24 tick, uint16, uint16, uint16, uint32, bool)',
    'function liquidity() view returns (uint128)',
  ], provider);
  const [slot0, liquidity] = await Promise.all([poolContract.slot0(), poolContract.liquidity()]);

  const t0 = new Token(ChainId.BSC, token.address, token.decimals, token.symbol);
  const t1 = new Token(ChainId.BSC, quoteToken.address, quoteToken.decimals, quoteToken.symbol);
  const pool = new Pool(t0, t1, feeTier, slot0.sqrtPriceX96.toString(), liquidity.toString(), slot0.tick);

  const tickSpacing = pool.tickSpacing;
  const delta = Math.round(Math.log(1 + priceIncreasePercent / 100) / Math.log(1.0001));
  let tickLower = nearestUsableTick(slot0.tick + delta, tickSpacing);
  let tickUpper = nearestUsableTick(slot0.tick + delta * 2, tickSpacing);
  if (tickLower <= slot0.tick) {
    tickLower = nearestUsableTick(slot0.tick + tickSpacing, tickSpacing);
    tickUpper = nearestUsableTick(slot0.tick + tickSpacing * 2, tickSpacing);
  }

  const amount0Desired = ethers.parseUnits(amountHuman, token.decimals);
  const position = Position.fromAmounts({
    pool, tickLower, tickUpper, amount0: amount0Desired.toString(), amount1: '0', useFullPrecision: false,
  });

  const mintAmounts = position.mintAmounts;
  await ensureApproval(token.address, NFPM_V3, BigInt(mintAmounts.amount0.toString()), account, signClient, session);
  if (BigInt(mintAmounts.amount1.toString()) > 0n) {
    await ensureApproval(quoteToken.address, NFPM_V3, BigInt(mintAmounts.amount1.toString()), account, signClient, session);
  }

  const { calldata, value } = NonfungiblePositionManager.addCallParameters(position, {
    slippageTolerance: new Percent(5, 1000), recipient: account, deadline: Math.floor(Date.now() / 1000) + 600,
  });
  await sendTxWithFix(signClient, session, { from: account, to: NFPM_V3, data: calldata, value, gas: '0x2dc6c0' });
}

// ========== 5. AI-АГЕНТ (ЦИКЛ WHILE TRUE) ==========
async function aiLoop(account, signClient, session) {
  console.log('\n🧠 AI-режим. Введіть запит (або "exit" для виходу).');
  console.log('Приклад: "створи пул V3 для мого токена 0x... з USDT, 1000 токенів, ціна x2"\n');

  while (true) {
    const userInput = await input({ message: 'Ви:' });
    if (userInput.toLowerCase() === 'exit') break;

    // Системний промпт: описуємо AI, які дії доступні
    const systemPrompt = `Ти — асистент для керування пулами PancakeSwap у Termux.
Доступні дії:
- createV3Position: створити односторонню V3-позицію. Потрібні параметри: token (адреса), quoteToken (адреса), feeTier (500, 2500, 10000), amountHuman (рядок), priceIncreasePercent (число).
- createV2Pool: створити пул V2. Потрібні: tokenA, tokenB, amountA (wei), amountB (wei).
Якщо користувач просить щось зробити, поверни ЛИШЕ JSON у форматі {"action": "...", "params": {...}}.
Якщо це запит на пояснення або код — поверни звичайний текст.`;

    try {
      const response = await fetch('https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: userInput },
          ],
          temperature: 0.2,
        }),
      });
      const data = await response.json();
      const reply = data.choices[0].message.content.trim();
      console.log('\n🤖 AI:', reply, '\n');

      // Якщо AI повернув JSON з дією — намагаємось виконати
      if (reply.startsWith('{')) {
        const cmd = JSON.parse(reply);
        if (cmd.action === 'createV3Position') {
          const p = cmd.params;
          const token = { address: p.token, decimals: 18, symbol: 'TOKEN' }; // decimals можна уточнити
          const quote = { address: p.quoteToken, decimals: 18, symbol: 'QUOTE' };
          await createV3Position({
            token, quoteToken: quote, feeTier: p.feeTier || FeeAmount.MEDIUM,
            amountHuman: p.amountHuman, priceIncreasePercent: p.priceIncreasePercent || 100,
            account, signClient, session,
          });
        } else if (cmd.action === 'createV2Pool') {
          await createV2Pool({
            tokenA: { address: cmd.params.tokenA }, tokenB: { address: cmd.params.tokenB },
            amountA: BigInt(cmd.params.amountA), amountB: BigInt(cmd.params.amountB),
            account, signClient, session,
          });
        } else {
          console.log('⚠️ Невідома дія:', cmd.action);
        }
      }
    } catch (e) {
      console.error('❌ Помилка AI:', e.message);
    }
  }
}

// ========== 6. ГОЛОВНЕ МЕНЮ ==========
(async () => {
  const projectId = process.env.WC_PROJECT_ID;
  if (!projectId) { console.error('❌ Додайте WC_PROJECT_ID у .env'); process.exit(1); }

  const { provider: p, rpcUrl: url } = await getWorkingProvider();
  provider = p; rpcUrl = url;

  const { signClient, session, account } = await connectWallet(projectId);

  while (true) {
    const action = await select({
      message: 'Оберіть дію:',
      choices: [
        { name: '🤖 AI-асистент (написати код / створити пул)', value: 'ai' },
        { name: '💧 Створити пул V2 (вручну)', value: 'v2' },
        { name: '🎯 Створити односторонню V3-позицію (вручну)', value: 'v3' },
        { name: '🚪 Вийти', value: 'exit' },
      ],
    });

    if (action === 'exit') break;

    if (action === 'ai') {
      await aiLoop(account, signClient, session);
    } else if (action === 'v2') {
      const tokenA = await chooseToken(account, signClient, session, 'Token A');
      const tokenB = await chooseToken(account, signClient, session, 'Token B');
      const amountA = await input({ message: `Скільки ${tokenA.symbol} внести?` });
      const amountB = await input({ message: `Скільки ${tokenB.symbol} внести?` });
      await ensureApproval(tokenA.address, ROUTER_V2, ethers.parseUnits(amountA, tokenA.decimals), account, signClient, session);
      await ensureApproval(tokenB.address, ROUTER_V2, ethers.parseUnits(amountB, tokenB.decimals), account, signClient, session);
      await createV2Pool({
        tokenA, tokenB,
        amountA: ethers.parseUnits(amountA, tokenA.decimals),
        amountB: ethers.parseUnits(amountB, tokenB.decimals),
        account, signClient, session,
      });
    } else if (action === 'v3') {
      const token = await chooseToken(account, signClient, session, 'ваш токен');
      const quote = await chooseToken(account, signClient, session, 'токен пари (USDT/WBNB)');
      const feeTier = await select({
        message: 'Рівень комісії:',
        choices: [
          { name: '0.05%', value: FeeAmount.LOWEST },
          { name: '0.25% (рекомендовано)', value: FeeAmount.MEDIUM },
          { name: '1%', value: FeeAmount.HIGH },
        ],
      });
      const amount = await input({ message: `Кількість ${token.symbol} для позиції:` });
      const increase = await input({ message: 'На скільки % вище ринку починати продаж? (наприклад, 100 = x2):', default: '100' });
      await createV3Position({
        token, quoteToken: quote, feeTier,
        amountHuman: amount, priceIncreasePercent: Number(increase),
        account, signClient, session,
      });
    }
  }
})().catch((e) => console.error('❌ Критична помилка:', e.shortMessage || e.message));
