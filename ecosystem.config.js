module.exports = {
  apps: [
    {
      name: "cybra-autonode-main",
      script: "/data/data/com.termux/files/home/CYBRA/bin/run_node.js",
      args: ["/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_main"],
      interpreter: "node",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    },
    {
      name: "cybra-autonode-cybra",
      script: "/data/data/com.termux/files/home/CYBRA/bin/run_node.js",
      args: ["/data/data/com.termux/files/home/CYBRA/bin/cybra_autonode_cybra"],
      interpreter: "node",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    },
    {
      name: "cybra-parliament-worker",
      script: "/data/data/com.termux/files/home/CYBRA/parliament_auto_worker.sh",
      interpreter: "bash",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    },
    {
      name: "cybra-parliament-priority",
      script: "/data/data/com.termux/files/home/CYBRA/parliament_core/priority_manager.py",
      args: ["daemon"],
      interpreter: "python3",
      cwd: "/data/data/com.termux/files/home/CYBRA",
      autorestart: true
    }
  ]
};
