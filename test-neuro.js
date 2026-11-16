require('dotenv').config();
const fs = require('fs');
const aiFixer = require('./modules/ai-fixer');

const TEST_FILE = './test_target.js';

// 1. Створюємо файл з НАВМИСНОЮ помилкою (синтаксис)
const brokenCode = `
// Тестовий файл для Нейро
function calculatePool(tick) {
  let result = tick * 2
  return result;
// ТУТ НАВМИСНО НЕ ВИСТАЧАЄ ДУЖКИ }
`;

fs.writeFileSync(TEST_FILE, brokenCode, 'utf8');
console.log('📝 Створено файл з помилкою (синтаксис):');
console.log('--------------------------------------------------');
console.log(brokenCode);
console.log('--------------------------------------------------');

(async () => {
  console.log('\n🧠 Відправляємо помилку в Нейро...');
  
  // 2. Викликаємо AI-Fixer
  const fixed = await aiFixer.fixCode(
    "SyntaxError: Unexpected end of input. Missing closing brace '}' for function calculatePool.", 
    TEST_FILE
  );

  // 3. Перевіряємо результат
  console.log('\n--------------------------------------------------');
  console.log('📄 Код після Нейро:');
  const newCode = fs.readFileSync(TEST_FILE, 'utf8');
  console.log(newCode);
  console.log('--------------------------------------------------');

  if (fixed) {
    console.log('\n✅ ТЕСТ ПРОЙДЕНО: Нейро виправила код!');
    if (fs.existsSync(TEST_FILE + '.bak')) {
      console.log('📦 Backup створено:', TEST_FILE + '.bak');
    }
  } else {
    console.log('\n❌ ТЕСТ ПРОВАЛЕНО: Нейро не змогла виправити.');
    console.log('Перевір: 1) Чи є ключ у .env  2) Чи є інтернет');
  }

  // Прибираємо
  if (fs.existsSync(TEST_FILE)) fs.unlinkSync(TEST_FILE);
  if (fs.existsSync(TEST_FILE + '.bak')) fs.unlinkSync(TEST_FILE + '.bak');
})();
