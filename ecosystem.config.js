module.exports = {
  apps: [
    {
      name: "cybra-autonode-main",
      script: "/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_main",
      interpreter: "bash",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true,
      cron_restart: "*/15 * * * *"
    },
    {
      name: "cybra-autonode-cybra",
      script: "/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_cybra",
      interpreter: "bash",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true,
      cron_restart: "*/15 * * * *"
    }
  ]
};
