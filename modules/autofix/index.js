// ~/CYBRA/modules/autofix/index.js
const { ethers } = require('ethers');

const CHAIN_ID = 'eip155:56';
const NFPM_V3 = '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364';

module.exports = {
  name: 'autofix',

  /**
   * Намагається зняти обмеження антиботу з токена.
   * @param {Object} ctx - контекст виконання
   * @param {string} tokenAddress - адреса токена, який треба розблокувати
   */
  async run(ctx, tokenAddress) {
    const { provider, signClient, session, account } = ctx;
    console.log(`[${this.name}] 🛠️ Запуск автофіксу для токена ${tokenAddress}...`);

    // ABI з усіма можливими функціями захисту
    const fixAbi = [
      'function enableTrading()',
      'function openTrading()',
      'function setTradingEnabled(bool)',
      'function setMaxTxAmount(uint256)',
      'function excludeFromFee(address)',
      'function setAutomatedMarketMakerPair(address,bool)'
    ];
    
    const contract = new ethers.Contract(tokenAddress, fixAbi, provider);
    const maxAmount = ethers.parseUnits('1000000000', 18); // 1 мільярд для зняття лімітів

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
        // Робимо "сухий прогін", щоб дізнатися, чи існує така функція
        await provider.call({ from: account, to: tokenAddress, data: fix.data });
        
        // Якщо помилки немає, функція існує і ми маємо право її викликати
        console.log(`[${this.name}] ✅ Знайдено функцію: ${fix.name}. Виконуємо...`);
        
        await signClient.request({
          topic: session.topic, chainId: CHAIN_ID,
          request: { method: 'eth_sendTransaction', params: [{ from: account, to: tokenAddress, data: fix.data, value: '0x0' }] },
        });
        
        console.log(`[${this.name}] 📤 Відправлено: ${fix.name}. Чекаємо 4 секунди...`);
        await new Promise(r => setTimeout(r, 4000));
        fixedAny = true;
      } catch (e) {
        // Якщо функції немає або ми не власник — просто йдемо далі
      }
    }

    if (!fixedAny) {
      console.log(`[${this.name}] ⚠️ Стандартних функцій не знайдено. Можливо, у вас інший захист.`);
    } else {
      console.log(`[${this.name}] ⏳ Чекаємо 5 секунд для оновлення блокчейну...`);
      await new Promise(r => setTimeout(r, 5000));
    }
    
    return fixedAny;
  }
};
