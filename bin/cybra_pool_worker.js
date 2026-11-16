require('dotenv').config();
const { SignClient } = require('@walletconnect/sign-client');
const rpc = require('../modules/rpc');
const security = require('../modules/security');
const notifier = require('../modules/notifier');
const aiFixer = require('../modules/ai-fixer');
const poolModule = require('../modules/pool_v3');

const CHAIN_ID = 'eip155:56';

async function initWalletConnect() {
  const signClient = await SignClient.init({ 
    projectId: process.env.WC_PROJECT_ID, 
    metadata: { name: 'CYBRA', description: 'AI', url: 'https://localhost', icons: [] } 
  });
  
  while (true) {
    try {
      const { uri, approval } = await signClient.connect({ 
        optionalNamespaces: { eip155: { methods: ['eth_sendTransaction'], chains: [CHAIN_ID], events: [] } } 
      });
      
      console.log('\n📱 НОВЕ ПОСИЛАННЯ ДЛЯ ПІДКЛЮЧЕННЯ:');
      console.log(`🦊 MetaMask: https://metamask.app.link/wc?uri=${encodeURIComponent(uri)}`);
      console.log(`🛡️ Trust Wallet: https://link.trustwallet.com/wc?uri=${encodeURIComponent(uri)}`);
      console.log('⏳ Чекаємо на підтвердження (якщо згорить, згенеруємо нове)...');
      
      const session = await approval();
      const account = session.namespaces.eip155.accounts[0].split(':')[2];
      console.log(`✅ Гаманець підключено: ${account}`);
      return { signClient, session, account };
    } catch (error) {
      console.log(`\n⚠️ Помилка підключення: ${error.message}. Нове посилання...`);
      await new Promise(r => setTimeout(r, 2000));
    }
  }
}

async function main() {
  console.log(`🚀 [WORKER] Старт системи...`);
  
  while (true) {
    try {
      // 1. Підключаємось до ноди (якщо впала - беремо іншу)
      const provider = await rpc.getProvider();
      
      // 2. Підключаємо гаманець (генеруємо посилання)
      const { signClient, session, account } = await initWalletConnect();

      const safeSignClient = {
        request: async (payload) => {
          if (payload.request && payload.request.method === 'eth_sendTransaction') {
            security.inspect(payload.request.params[0]);
          }
          return signClient.request(payload);
        }
      };
      
      const ctx = { provider, signClient: safeSignClient, session, account, env: process.env };

      console.log(`\n🔄 Спроба створити/додати ліквідність...`);
      const result = await poolModule.run(ctx);
      
      console.log('✅ УСПІХ!', result);
      await notifier.send('Пул створено!', `Pool: ${result.poolAddress}\nTX: ${result.txHash}`, 'success');
      process.exit(0); // Виходимо, якщо все ідеально

    } catch (err) {
      console.error(`\n❌ ПОМИЛКА: ${err.message}`);

      // --- АНАЛІЗ ПОМИЛОК ---
      
      // 1. Втрата інтернету або DNS (ENOTFOUND)
      if (err.message.includes('ENOTFOUND') || err.message.includes('EAI_AGAIN') || err.message.includes('network')) {
        console.log('🌐 Мережевий збій. Скидаємо RPC і пробуємо іншу ноду...');
        rpc.reset();
        await new Promise(r => setTimeout(r, 3000));
        continue; // Повертаємось на початок (перепідключення до ноди)
      }

      // 2. Сесія гаманця згоріла (Request expired) або користувач відхилив
      if (err.message.includes('Request expired') || err.message.includes('User disapproved') || err.message.includes('User rejected')) {
        console.log('⏳ Сесія WalletConnect згоріла або транзакцію відхилено.');
        console.log('💡 Перегенеровуємо посилання для підключення...');
        await new Promise(r => setTimeout(r, 2000));
        continue; // Повертаємось на початок (генеруємо нове посилання)
      }

      // 3. Помилка безпеки (MaxUint256)
      if (err.message.includes('SECURITY')) {
        console.log('🛑 Контролер безпеки заблокував транзакцію!');
        await notifier.send('Заблоковано безпекою', err.message, 'warn');
        process.exit(0); 
      }

      // 4. Логічні помилки коду (AI-Fixer)
      console.log('🧠 Логічна помилка. Передаємо Нейро (AI)...');
      const fixed = await aiFixer.fixCode(err.message, './modules/pool_v3/index.js');
      
      if (fixed) {
        console.log('🔄 AI виправив код! PM2 перезапустить систему...');
        process.exit(1); 
      } else {
        console.log('⚠️ AI не зміг виправити (немає ключа або патч не застосовано).');
        console.log('🔄 Повторна спроба через 15 секунд...');
        await new Promise(r => setTimeout(r, 15000));
        continue;
      }
    }
  }
}

main().catch(e => { console.error('❌ CRITICAL:', e.message); process.exit(1); });
