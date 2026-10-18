#!/data/data/com.termux/files/usr/bin/bash
CYBRA="$HOME/CYBRA"

echo "═══ 1. ВІДНОВЛЕННЯ ОБГОРТКИ (run_node.js) ═══"
mkdir -p "$CYBRA/bin"
cat > "$CYBRA/bin/run_node.js" << 'EOF'
const { spawn } = require('child_process');
const path = process.argv[2];
if (!path) { console.error('No script path'); process.exit(1); }
const child = spawn('/data/data/com.termux/files/usr/bin/bash', [path], {
    env: { ...process.env, HOME: '/data/data/com.termux/files/home', PATH: '/data/data/com.termux/files/usr/bin:/data/data/com.termux/files/home/bin' },
    stdio: 'inherit'
});
child.on('exit', (code) => process.exit(code));
EOF
echo "  [✓] run_node.js відновлено"

echo ""
echo "═══ 2. ПЕРЕЗАПУСК PM2 ═══"
pm2 delete all 2>/dev/null
pm2 start "$CYBRA/ecosystem.config.js"
pm2 save 2>/dev/null

echo ""
echo "═══ 3. СКАНУВАННЯ МОДУЛІВ (створення registry.json) ═══"
python3 "$CYBRA/parliament_core/priority_manager.py" scan

echo ""
echo "═══ 4. СТАТУС PM2 ═══"
pm2 status
