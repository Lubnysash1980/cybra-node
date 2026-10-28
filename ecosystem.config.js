module.exports = {
  apps: [
    { name: "cybra-ai-a",   script: "./scripts/ai-writer.py", args: "a", cron_restart: "*/30 * * * *", autorestart: false, interpreter: "python3" },
    { name: "cybra-sync-a", script: "./scripts/prog-sync.sh", args: "a", cron_restart: "*/31 * * * *", autorestart: false },
    { name: "cybra-ai-b",   script: "./scripts/ai-writer.py", args: "b", cron_restart: "*/30 * * * *", autorestart: false, interpreter: "python3" },
    { name: "cybra-sync-b", script: "./scripts/prog-sync.sh", args: "b", cron_restart: "*/31 * * * *", autorestart: false },
  ]
};
