#!/usr/bin/env node
// CYBRA watchdog — if kill -> start_pm2 (Node.js версія для PM2)

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const HOME = process.env.HOME;
const LOG = path.join(HOME, 'CYBRA', 'logs', 'watchdog.log');
const INTERVAL_MS = 30 * 1000;
const EXPECTED = 9;

function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}\n`;
  try { fs.appendFileSync(LOG, line); } catch (e) {}
}

function countOnline() {
  try {
    const out = execSync('pm2 ls 2>/dev/null', { encoding: 'utf8' });
    // Рахуємо тільки рядки online, ВИКЛЮЧАЮЧИ сам watchdog
    return out.split('\n').filter(line =>
      line.includes('online') && !line.includes('cybra-watchdog')
    ).length;
  } catch (e) { return 0; }
}

function resurrect() {
  try {
    execSync('pm2 resurrect', { cwd: path.join(HOME, 'CYBRA'), stdio: 'ignore' });
  } catch (e) {}
}

log(`=== Watchdog Start (interval=${INTERVAL_MS/1000}s, expected=${EXPECTED}) ===`);

setInterval(() => {
  const online = countOnline();
  log(`check: online(without watchdog)=${online}`);
  if (online < EXPECTED) {
    log(`ALERT: online=${online} < expected=${EXPECTED} — resurrect`);
    resurrect();
    setTimeout(() => {
      log(`RESURRECT: now online=${countOnline()}`);
    }, 3000);
  }
}, INTERVAL_MS);
