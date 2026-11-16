require('dotenv').config();
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const notifier = require('../modules/notifier');

const QUEUE_KEY = 'cybra:ai:tasks:block_inbox';
const AI_BASE_URL = process.env.AI_BASE_URL || 'http://127.0.0.1:11434/v1';
const AI_MODEL = process.env.AI_MODEL || 'cybra-parliament';
const AI_KEY = process.env.AI_API_KEY || 'local';

// Використовуємо redis-cli, щоб не тягнути зайві npm-пакети
function popTask() {
  try {
    const out = execSync(`redis-cli RPOP "${QUEUE_KEY}"`).toString().trim();
    if (!out || out === 'nil') return null;
    return JSON.parse(out);
  } catch (e) {
    return null;
  }
}

async function askNeuroDepartment(errorMsg, code) {
  const prompt = `Ти — CYBRA Neuro Department (AI-Fix Subcommittee). 
Сталася помилка: "${errorMsg}".
Ось код:
\`\`\`javascript
${code}
\`\`\`
Виправ помилку і поверни ТІЛЬКИ повний, робочий JavaScript код файлу. Без маркдауну, без пояснень.`;

  console.log(`[neuro] 🧠 Відправка запиту в Нейро-Департамент (${AI_MODEL})...`);
  
  const resp = await fetch(`${AI_BASE_URL.replace(/\/$/, '')}/chat/completions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${AI_KEY}` },
    body: JSON.stringify({
      model: AI_MODEL,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.1
    })
  });

  if (!resp.ok) throw new Error(`Neuro API Error: HTTP ${resp.status}`);
  const data = await resp.json();
  let fixedCode = data.choices[0].message.content.trim();
  
  if (fixedCode.startsWith('```javascript')) fixedCode = fixedCode.slice(13);
  if (fixedCode.startsWith('```')) fixedCode = fixedCode.slice(3);
  if (fixedCode.endsWith('```')) fixedCode = fixedCode.slice(0, -3);
  
  return fixedCode.trim() + '\n';
}

async function processTask(task) {
  console.log(`\n[neuro] 🏛️ Neuro Department отримав задачу: ${task.payload.text}`);
  
  const match = task.payload.text.match(/в (\.\/.*?):/);
  const filePath = match ? match[1] : './modules/pool_v3/index.js';
  const targetFile = path.resolve(__dirname, '..', filePath);

  if (!fs.existsSync(targetFile)) {
    console.log(`[neuro] ❌ Файл не знайдено: ${targetFile}`);
    return;
  }

  const originalCode = fs.readFileSync(targetFile, 'utf8');
  
  try {
    const fixedCode = await askNeuroDepartment(task.payload.text, originalCode);
    
    fs.writeFileSync(targetFile + '.bak', originalCode);
    fs.writeFileSync(targetFile, fixedCode);
    
    console.log(`[neuro] ✅ Нейро-Департамент виніс рішення! Код оновлено: ${filePath}`);
    
    // Логуємо звіт у папку Нейро-Департаменту
    const report = {
      time: new Date().toISOString(),
      task: task.payload.text,
      file: filePath,
      status: "fixed",
      model: AI_MODEL
    };
    fs.appendFileSync(path.resolve(__dirname, '../data/cybra_neuro_department/reports/fixes.jsonl'), JSON.stringify(report) + '\n');

    await notifier.send('Neuro Department: Fix OK', `AI виправив код у ${filePath}. PM2 перезапустить воркер.`, 'success');
    
    console.log(`[neuro] 🔄 Перезапуск cybra-pool...`);
    execSync(`pm2 restart cybra-pool`, { stdio: 'ignore' });
    
  } catch (e) {
    console.error(`[neuro] ❌ Помилка Нейро: ${e.message}`);
    await notifier.send('Neuro Department: Error', `Не вдалося виправити ${filePath}: ${e.message}`, 'error');
  }
}

async function main() {
  console.log(`🚀 [NEURO DEPARTMENT] Аналітичний центр запущено.`);
  console.log(`   Слухаємо чергу: ${QUEUE_KEY}`);
  console.log(`   AI Endpoint: ${AI_BASE_URL}`);

  while (true) {
    const task = popTask();
    if (task) {
      await processTask(task);
    } else {
      await new Promise(r => setTimeout(r, 5000));
    }
  }
}

main().catch(e => console.error('❌ CRITICAL NEURO ERROR:', e.message));
