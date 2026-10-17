#!/usr/bin/env python3
import os, subprocess
from pathlib import Path

HOME = Path(os.environ["HOME"])
CYBRA = HOME / "CYBRA"

def run(cmd, cwd=None):
    return subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)

print("═══ 1. СТВОРЕННЯ NODE-ОБГОРТКИ ═══")
runner = CYBRA / "bin" / "run_node.js"
runner_content = """const { spawn } = require('child_process');
const path = process.argv[2];
if (!path) { console.error('No script path'); process.exit(1); }

const child = spawn('/data/data/com.termux/files/usr/bin/bash', [path], {
    env: {
        ...process.env,
        HOME: '/data/data/com.termux/files/home',
        PATH: '/data/data/com.termux/files/usr/bin:/data/data/com.termux/files/home/bin'
    },
    stdio: 'inherit'
});
child.on('exit', (code) => process.exit(code));
"""
runner.write_text(runner_content)
print(f"  [✓] {runner.name}")

print("\n═══ 2. ОНОВЛЕННЯ ecosystem.config.js ═══")
eco_content = """module.exports = {
  apps: [
    {
      name: "cybra-autonode-main",
      script: "/data/data/com.termux/files/home/CYBRA/bin/run_node.js",
      args: ["/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_main"],
      interpreter: "node",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true,
      cron_restart: "*/15 * * * *"
    },
    {
      name: "cybra-autonode-cybra",
      script: "/data/data/com.termux/files/home/CYBRA/bin/run_node.js",
      args: ["/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_cybra"],
      interpreter: "node",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true,
      cron_restart: "*/15 * * * *"
    }
  ]
};
"""
(CYBRA / "ecosystem.config.js").write_text(eco_content)
print("  [✓] ecosystem.config.js")

print("\n═══ 3. ПЕРЕЗАПУСК PM2 ═══")
run("pm2 delete all")
run("pm2 start ~/CYBRA/ecosystem.config.js")
run("pm2 save")
r = run("pm2 status")
print(r.stdout)

print("\n═══ 4. КОМІТ У GIT ═══")
run("git add bin/run_node.js ecosystem.config.js", cwd=str(CYBRA))
r = run('git commit -m "fix: node wrapper for pm2 nodes"', cwd=str(CYBRA))
print(r.stdout)
