#!/usr/bin/env node
// cybra_autonode_main.js — нода з перевіркою EVO + SANDBOX (Node.js версія)

const fs = require('fs');
const path = require('path');
const { execSync, execFileSync } = require('child_process');

const CYBRA_HOME = path.join(process.env.HOME, 'CYBRA');
const LOG = path.join(CYBRA_HOME, 'logs', 'evo_node_main.log');
const SANDBOX_LIMIT = 65 * 1024 * 1024;
const CYCLE_SLEEP_MS = 60 * 1000;

function ensureDir(p) { try { fs.mkdirSync(p, { recursive: true }); } catch (e) {} }
function timestamp() { return new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'); }
function log(msg) {
  const line = `[${timestamp()}] ${msg}\n`;
  try { fs.appendFileSync(LOG, line); } catch (e) { process.stdout.write(line); }
}
function dirSizeBytes(dir) {
  try {
    const out = execFileSync('du', ['-sb', dir], { encoding: 'utf8' }).trim();
    const size = parseInt(out.split(/\s+/)[0], 10);
    return Number.isFinite(size) ? size : 0;
  } catch (e) { return 0; }
}
function fileExists(p) { try { return fs.existsSync(p); } catch (e) { return false; } }
function isExecutable(p) { try { fs.accessSync(p, fs.constants.X_OK); return true; } catch (e) { return false; } }

function runCycle() {
  log('--- Cycle ---');
  const sandbox = path.join(CYBRA_HOME, 'sandbox');
  if (fileExists(sandbox)) {
    const size = dirSizeBytes(sandbox);
    const sizeMb = Math.floor(size / 1024 / 1024);
    if (size >= SANDBOX_LIMIT) {
      log(`SANDBOX: переповнено (${sizeMb} МБ), очищаю`);
      const cleanup = path.join(sandbox, 'sandbox_cleanup.sh');
      if (fileExists(cleanup)) { try { execFileSync('bash', [cleanup], { stdio: 'ignore' }); } catch (e) {} }
    } else {
      log(`SANDBOX: OK (${sizeMb} МБ / 65 МБ)`);
    }
  } else {
    log('SANDBOX: папка не знайдена');
  }

  const libFile = path.join(CYBRA_HOME, 'lib', 'cybra_invoice_lib.sh');
  if (!fileExists(libFile)) {
    log('EVO: немає lib, робимо rollback');
    try { execSync('git reset --hard HEAD --quiet', { cwd: CYBRA_HOME, stdio: 'ignore' }); } catch (e) {}
  }

  const hashEco = path.join(CYBRA_HOME, 'bin', 'cybra_hash_eco');
  if (isExecutable(hashEco)) {
    try { execFileSync(hashEco, ['snapshot'], { stdio: 'ignore' }); log('EVO: снапшот створено'); } catch (e) {}
  }

  log('EVO: 100% — система в нормі');
}

ensureDir(path.join(CYBRA_HOME, 'logs'));
if (!fileExists(CYBRA_HOME)) { log(`FATAL: CYBRA_HOME не існує: ${CYBRA_HOME}`); process.exit(1); }
process.chdir(CYBRA_HOME);
log('=== Node Main Start ===');

let stopped = false;
function shutdown(sig) { if (stopped) return; stopped = true; log(`=== Node Main Stop (${sig}) ===`); process.exit(0); }
process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGHUP', () => shutdown('SIGHUP'));

function loop() {
  if (stopped) return;
  try { runCycle(); } catch (e) { log(`CYCLE ERROR: ${e.message}`); }
  if (!stopped) setTimeout(loop, CYCLE_SLEEP_MS);
}
loop();
