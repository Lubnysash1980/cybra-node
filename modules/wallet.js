'use strict';
const fs = require('fs');
const path = require('path');

const out = {};
const dirs = fs
  .readdirSync(__dirname)
  .filter((d) => d.startsWith('module_') && /wallet/i.test(d));

for (const d of dirs) {
  const dir = path.join(__dirname, d);
  if (!fs.statSync(dir).isDirectory()) continue;

  // 1) спробувати index.*
  const idx = ['index.js', 'index.cjs', 'index.mjs']
    .map((f) => path.join(dir, f))
    .find((p) => fs.existsSync(p));

  const entries = idx
    ? [idx]
    : fs
        .readdirSync(dir)
        .filter((f) => f.endsWith('.js') || f.endsWith('.cjs'))
        .map((f) => path.join(dir, f));

  if (!entries.length) {
    process.stderr.write(`[wallet] no entry in ${d}\n`);
    continue;
  }

  for (const p of entries) {
    try {
      const m = require(p);
      Object.assign(out, m && m.__esModule ? m : { ...m });
    } catch (e) {
      process.stderr.write(`[wallet] skip ${path.relative(__dirname, p)}: ${e.message}\n`);
    }
  }
}

process.stderr.write(`[wallet] exports: ${Object.keys(out).join(', ') || '(empty)'}\n`);
module.exports = out;
