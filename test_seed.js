require('dotenv').config();
const walletModule = require('./modules/wallet');

const seed = process.env.SECRET_RECOVERY_PHRASE || process.env.WALLET_MNEMONIC;
if (!seed) {
  console.error('❌ Немає SECRET_RECOVERY_PHRASE у .env');
  process.exit(1);
}

try {
  const info = walletModule.peek(seed);
  console.log('✅ Сід-фраза валідна');
  console.log('📍 Адреса:', info.address);
  console.log('🔑 Ключ:', info.keyPreview, `(${info.keyLength} символів)`);
  console.log('');
  if (info.address.toLowerCase() === '0x9f6b6054d74052c98142a4c3797a078eddd48c58') {
    console.log('🎯 Адреса збігається з твоїм гаманцем!');
  } else {
    console.log('⚠️ Адреса НЕ збігається. Можливо, це не та сід-фраза.');
  }
} catch (e) {
  console.error('❌ Помилка:', e.message);
}
