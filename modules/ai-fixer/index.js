const path = require('path');
const { execSync } = require('child_process');
const notifier = require('../notifier');

module.exports = {
  async fixCode(errorMsg, filePath) {
    console.log(`\n[ai-fixer] 🏛️ Звертаємось до CYBRA Parliament (IT Department)...`);
    try {
      const taskText = `[AI-FIX REQUEST] Помилка в ${filePath}: ${errorMsg}`;
      const safeTaskText = taskText.replace(/"/g, '\\"');
      
      console.log(`[ai-fixer] 📤 Відправка задачі в Redis-чергу Парламенту...`);
      execSync(`cybra-it task "${safeTaskText}"`, { cwd: path.resolve(__dirname, '../../') });
      
      console.log(`[ai-fixer] ✅ Задача створена. Парламент аналізує...`);
      await notifier.send('Parliament Task Created', `AI-Fix задача для ${filePath} відправлена в IT-Департамент.`, 'info');
    } catch (e) {
      console.error(`[ai-fixer] ❌ Не вдалося створити задачу в Парламенті: ${e.message}`);
    }
    return false; 
  }
};
