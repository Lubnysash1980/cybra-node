require('dotenv').config();
const { ethers } = require('ethers');

let PASS = 0, FAIL = 0;
function ok(name, expected, actual) {
  console.log(`  ✅ PASS | ${name}`);
  console.log(`          Очікувалось: ${expected}`);
  console.log(`          Отримано:    ${actual}`);
  PASS++;
}
function bad(name, expected, actual, reason) {
  console.log(`  ❌ FAIL | ${name}`);
  console.log(`          Очікувалось: ${expected}`);
  console.log(`          Отримано:    ${actual}`);
  if (reason) console.log(`          Причина: ${reason}`);
  FAIL++;
}

async function testRPC() {
  console.log('\n▶ ТЕСТ 1: RPC модуль');
  console.log('   Завдання: підключитися до BSC і отримати номер блоку');
  try {
    const rpc = require('./modules/rpc');
    const provider = await rpc.getProvider();
    const block = await provider.getBlockNumber();
    
    if (block > 100000000) {
      ok('getProvider + getBlockNumber', '> 100 000 000', block);
    } else {
      bad('getProvider + getBlockNumber', '> 100 000 000', block, 'Блок замалий — можливо, стара нода');
    }
    console.log(`  📡 Активна нода: ${rpc.getCurrentUrl()}`);
  } catch (e) {
    bad('getProvider', 'блок > 0', `ПОМИЛКА: ${e.message}`);
  }
}

async function testSecurity() {
  console.log('\n▶ ТЕСТ 2: Security контролер');
  const security = require('./modules/security');
  const iface = new ethers.Interface(['function approve(address,uint256)']);
  const SPENDER = '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364';

  // Тест 2.1 — точна сума (має ПРОПУСТИТИ)
  console.log('   Завдання 2.1: approve(100 CYBRA) має пройти');
  try {
    const data = iface.encodeFunctionData('approve', [SPENDER, ethers.parseUnits('100', 18)]);
    security.inspect({ to: '0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f', data });
    ok('approve(100) дозволено', 'без помилок', 'без помилок');
  } catch (e) {
    bad('approve(100) дозволено', 'без помилок', `ПОМИЛКА: ${e.message}`);
  }

  // Тест 2.2 — MaxUint256 (має ЗАБЛОКУВАТИ)
  console.log('   Завдання 2.2: approve(MaxUint256) має бути заблоковано');
  try {
    const data = iface.encodeFunctionData('approve', [SPENDER, ethers.MaxUint256]);
    security.inspect({ to: '0x74dA52028E42A37bc89E05c2fD5c52daBE4CB48f', data });
    bad('approve(MaxUint256) заблоковано', 'SECURITY помилка', 'транзакція пройшла (небезпека!)');
  } catch (e) {
    if (e.message.includes('SECURITY')) {
      ok('approve(MaxUint256) заблоковано', 'SECURITY помилка', 'SECURITY помилка');
    } else {
      bad('approve(MaxUint256) заблоковано', 'SECURITY помилка', e.message);
    }
  }

  // Тест 2.3 — не approve транзакція (має ПРОПУСТИТИ)
  console.log('   Завдання 2.3: звичайна транзакція (не approve) — пропустити');
  try {
    security.inspect({ to: '0x46A15B0b27311cedF172AB29E4f4766fbE7F4364', data: '0x12345678' });
    ok('звичайна транзакція дозволена', 'без помилок', 'без помилок');
  } catch (e) {
    bad('звичайна транзакція дозволена', 'без помилок', e.message);
  }
}

async function testV3Math() {
  console.log('\n▶ ТЕСТ 3: Математика V3 (тіки)');
  console.log('   Завдання: розрахувати діапазон для продажу CYBRA на 100% вище');
  try {
    const { nearestUsableTick } = require('@pancakeswap/v3-sdk');
    const currentTick = 0;
    const tickSpacing = 50;
    const priceIncrease = 100; // %
    const delta = Math.round(Math.log(1 + priceIncrease / 100) / Math.log(1.0001));
    // Для продажу (token1) — діапазон НИЖЧЕ ринку
    const tickUpper = nearestUsableTick(currentTick - tickSpacing, tickSpacing);
    const tickLower = nearestUsableTick(tickUpper - delta, tickSpacing);

    // Перевірка: діапазон має бути нижче 0 і кратним 50
    const valid = tickLower < tickUpper && tickUpper < 0 && tickLower % 50 === 0 && tickUpper % 50 === 0;
    if (valid) {
      ok('Діапазон для продажу', 'tickLower < tickUpper < 0', `[${tickLower}, ${tickUpper}]`);
    } else {
      bad('Діапазон для продажу', 'tickLower < tickUpper < 0', `[${tickLower}, ${tickUpper}]`);
    }
    console.log(`  📊 delta = ${delta} тіків (≈ +${priceIncrease}% ціни)`);
  } catch (e) {
    bad('Математика V3', 'числа', `ПОМИЛКА: ${e.message}`);
  }
}

async function testAIFixer() {
  console.log('\n▶ ТЕСТ 4: AI-Fixer (Нейро)');
  console.log('   Завдання: викликати Нейро і перевірити, чи вона відповідає');
  
  const hasKey = !!(process.env.OPENAI_API_KEY || process.env.DEEPSEEK_API_KEY);
  console.log(`  🔑 AI ключ: ${hasKey ? 'Є' : 'НЕМАЄ'}`);

  const aiFixer = require('./modules/ai-fixer');
  
  // Тест 4.1: функція існує
  if (typeof aiFixer.fixCode === 'function') {
    ok('fixCode — це функція', 'function', typeof aiFixer.fixCode);
  } else {
    bad('fixCode — це функція', 'function', typeof aiFixer.fixCode);
  }

  // Тест 4.2: без ключа має повернути false
  if (!hasKey) {
    console.log('   Завдання 4.2: без ключа AI має повернути false (не падати)');
    const result = await aiFixer.fixCode('fake error', './modules/pool_v3/index.js');
    if (result === false) {
      ok('Без ключа → false', 'false', 'false');
    } else {
      bad('Без ключа → false', 'false', result, 'AI повернула true без ключа — дивно!');
    }
  } else {
    console.log('   Завдання 4.2: з ключем AI має бути викликана');
    console.log('  ⏭️  Пропускаємо (не хочемо реально викликати AI, щоб не витрачати токени)');
    console.log('  💡 Запусти ./test-ai.js для реального тесту');
  }
}

async function testNotifier() {
  console.log('\n▶ ТЕСТ 5: Notifier (Email)');
  console.log('   Завдання: перевірити, що notifier.send існує і не падає');

  const notifier = require('./modules/notifier');
  if (typeof notifier.send === 'function') {
    ok('send — це функція', 'function', typeof notifier.send);
  } else {
    bad('send — це функція', 'function', typeof notifier.send);
  }

  const hasEmail = !!(process.env.EMAIL_USER && process.env.EMAIL_PASS);
  console.log(`  📧 Email налаштовано: ${hasEmail ? 'ТАК' : 'НІ'}`);
  
  if (hasEmail) {
    console.log('   Завдання 5.2: надіслати тестовий лист');
    try {
      await notifier.send('CYBRA Test', 'Тестовий лист від module-tests.js', 'info');
      ok('Лист надіслано', 'без помилок', 'без помилок (перевір пошту!)');
    } catch (e) {
      bad('Лист надіслано', 'без помилок', e.message);
    }
  } else {
    console.log('  ⏭️  Пропускаємо — email не налаштований');
  }
}

async function testPoolV3Module() {
  console.log('\n▶ ТЕСТ 6: Pool_V3 (модуль існує і правильно імпортує)');
  try {
    const pool = require('./modules/pool_v3');
    if (pool.name === 'pool_v3') {
      ok('Модуль pool_v3 завантажено', 'name=pool_v3', `name=${pool.name}`);
    } else {
      bad('Модуль pool_v3 завантажено', 'name=pool_v3', `name=${pool.name}`);
    }
    if (typeof pool.run === 'function') {
      ok('Функція run існує', 'function', typeof pool.run);
    } else {
      bad('Функція run існує', 'function', typeof pool.run);
    }
  } catch (e) {
    bad('Імпорт pool_v3', 'модуль завантажується', `ПОМИЛКА: ${e.message}`);
  }
}

(async () => {
  console.log('╔════════════════════════════════════════════╗');
  console.log('║  CYBRA MODULE TESTS — юніт-тести з відповідями ║');
  console.log('╚════════════════════════════════════════════╝');

  await testRPC();
  await testSecurity();
  await testV3Math();
  await testAIFixer();
  await testNotifier();
  await testPoolV3Module();

  console.log('\n╔════════════════════════════════════════════╗');
  console.log(`║  РЕЗУЛЬТАТ: ✅ ${PASS} PASS  |  ❌ ${FAIL} FAIL`);
  console.log('╚════════════════════════════════════════════╝');

  if (FAIL === 0) {
    console.log('🎉 ВСІ МОДУЛІ ПРАЦЮЮТЬ ПРАВИЛЬНО!');
  } else {
    console.log(`⚠️  ${FAIL} модулів потребують уваги.`);
  }
  process.exit(FAIL > 0 ? 1 : 0);
})();
