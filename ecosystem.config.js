const path = require("path");
const fs = require("fs");

const ROOT = path.resolve(process.env.CYBRA_HOME || __dirname);
const LOG_DIR = path.join(ROOT, "logs");
const PYTHON = process.env.PYTHON_BIN || "python3";
fs.mkdirSync(LOG_DIR, { recursive: true });

function app(name, script, args = [], interpreter = PYTHON, options = {}) {
  return {
    name,
    script: path.join(ROOT, script),
    args,
    interpreter,
    cwd: ROOT,
    autorestart: true,
    min_uptime: "10s",
    max_restarts: 20,
    exp_backoff_restart_delay: 100,
    kill_timeout: 10000,
    listen_timeout: 10000,
    merge_logs: true,
    time: true,
    out_file: path.join(LOG_DIR, name + ".out.log"),
    error_file: path.join(LOG_DIR, name + ".err.log"),
    env: { PYTHONUNBUFFERED: "1" },
    ...options
  };
}

module.exports = {
  apps: [
    app("cybra-autonode", "modules/module_114_autonode/daemon.py"),
    app("cybra-watchdog", "modules/module_121_parlament/watchdog.sh", ["daemon"], "bash"),
    app("cybra-orchestrator", "modules/module_121_parlament/orchestrator.py",
        ["daemon", "--interval", "600"]),
    // executor.py auto is a one-shot task; PM2 must not restart it in a loop.
    app("cybra-executor", "modules/module_121_parlament/executor.py",
        ["auto"], PYTHON, { autorestart: false, max_restarts: 0 })
  ]
};
