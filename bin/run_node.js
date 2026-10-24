const { spawn } = require('child_process');
const path = process.argv[2];
if (!path) { console.error('No script path'); process.exit(1); }
const child = spawn('/data/data/com.termux/files/usr/bin/bash', [path], {
    env: { ...process.env, HOME: '/data/data/com.termux/files/home', PATH: '/data/data/com.termux/files/usr/bin:/data/data/com.termux/files/home/bin' },
    stdio: 'inherit'
});
child.on('exit', (code) => process.exit(code));
