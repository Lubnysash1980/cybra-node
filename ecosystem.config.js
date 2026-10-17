module.exports = {
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
